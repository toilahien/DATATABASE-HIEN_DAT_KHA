-- Leases must be submitted pending, approved by an active Admin, then ended.
USE reims_db;
DELIMITER $$

DROP TRIGGER IF EXISTS trg_lease_guard_insert$$
CREATE TRIGGER trg_lease_guard_insert
BEFORE INSERT ON lease
FOR EACH ROW
BEGIN
    DECLARE v_property_status VARCHAR(30);
    DECLARE v_listing_type VARCHAR(20);

    IF NEW.status <> 'PENDING' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'A lease must be submitted as PENDING and approved before activation';
    END IF;
    IF NEW.reviewed_by_account_id IS NOT NULL OR NEW.reviewed_at IS NOT NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'A new lease cannot contain review details';
    END IF;

    SELECT status, listing_type INTO v_property_status, v_listing_type
    FROM property WHERE property_id = NEW.property_id FOR UPDATE;
    IF v_property_status <> 'AVAILABLE' OR v_listing_type <> 'FOR_RENT' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'A pending lease requires an AVAILABLE rental property';
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_lease_guard_update$$
CREATE TRIGGER trg_lease_guard_update
BEFORE UPDATE ON lease
FOR EACH ROW
BEGIN
    DECLARE v_property_status VARCHAR(30);
    DECLARE v_listing_type VARCHAR(20);

    IF NEW.start_date <> OLD.start_date OR NEW.end_date <> OLD.end_date
       OR NEW.monthly_rent <> OLD.monthly_rent OR NEW.deposit_amount <> OLD.deposit_amount
       OR NEW.payment_day <> OLD.payment_day OR NEW.property_id <> OLD.property_id
       OR NEW.tenant_id <> OLD.tenant_id OR NEW.agent_id <> OLD.agent_id THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Lease terms and parties are immutable after submission';
    END IF;
    IF NEW.deposit_paid <> OLD.deposit_paid
       AND COALESCE(@reims_payment_balance_sync, 0) <> 1 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Deposit balance is maintained by payment records';
    END IF;

    IF NEW.status = OLD.status THEN
        IF NOT (NEW.reviewed_by_account_id <=> OLD.reviewed_by_account_id)
           OR NOT (NEW.reviewed_at <=> OLD.reviewed_at) THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Review details change only during Admin review';
        END IF;
    ELSEIF OLD.status = 'PENDING' AND NEW.status IN ('ACTIVE', 'REJECTED') THEN
        IF NEW.reviewed_by_account_id IS NULL OR NEW.reviewed_at IS NULL OR NOT EXISTS (
            SELECT 1 FROM user_account
            WHERE account_id = NEW.reviewed_by_account_id
              AND actor_role = 'ADMIN' AND is_active = TRUE
        ) THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Lease review requires an active Admin account and timestamp';
        END IF;

        IF NEW.status = 'ACTIVE' THEN
            SELECT status, listing_type INTO v_property_status, v_listing_type
            FROM property WHERE property_id = NEW.property_id FOR UPDATE;
            IF v_property_status <> 'AVAILABLE' OR v_listing_type <> 'FOR_RENT' THEN
                SIGNAL SQLSTATE '45000'
                    SET MESSAGE_TEXT = 'An active lease requires an AVAILABLE rental property';
            END IF;
        END IF;
    ELSEIF OLD.status = 'ACTIVE' AND NEW.status IN ('EXPIRED', 'TERMINATED') THEN
        IF NOT (NEW.reviewed_by_account_id <=> OLD.reviewed_by_account_id)
           OR NOT (NEW.reviewed_at <=> OLD.reviewed_at) THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lease review details cannot be rewritten';
        END IF;
    ELSE
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid lease status transition';
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_lease_sync_insert$$

DROP TRIGGER IF EXISTS trg_lease_sync_update$$
CREATE TRIGGER trg_lease_sync_update
AFTER UPDATE ON lease
FOR EACH ROW
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SET @reims_property_sync = NULL;
        RESIGNAL;
    END;
    IF OLD.status <> NEW.status THEN
        IF NEW.status = 'ACTIVE' THEN
            SET @reims_property_sync = 1;
            UPDATE property SET status = 'LEASED' WHERE property_id = NEW.property_id;
            SET @reims_property_sync = NULL;
        ELSEIF OLD.status = 'ACTIVE' THEN
            SET @reims_property_sync = 1;
            UPDATE property p
            SET p.status = CASE
                WHEN EXISTS (
                    SELECT 1 FROM maintenance_request m
                    JOIN lease ml ON ml.lease_id = m.lease_id
                    WHERE ml.property_id = NEW.property_id AND m.status = 'IN_PROGRESS'
                ) THEN 'UNDER_MAINTENANCE'
                ELSE 'AVAILABLE'
            END
            WHERE p.property_id = NEW.property_id;
            SET @reims_property_sync = NULL;
        END IF;
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_lease_no_delete$$
CREATE TRIGGER trg_lease_no_delete
BEFORE DELETE ON lease
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Lease history cannot be deleted';
END$$
DELIMITER ;
