-- Sale offers must be submitted pending and reviewed by an active Admin.
USE reims_db;
DELIMITER $$

DROP TRIGGER IF EXISTS trg_sale_guard_insert$$
CREATE TRIGGER trg_sale_guard_insert
BEFORE INSERT ON sale_transaction
FOR EACH ROW
BEGIN
    DECLARE v_property_status VARCHAR(30);
    DECLARE v_listing_type VARCHAR(20);
    DECLARE v_assigned_agent BIGINT UNSIGNED;
    DECLARE v_commission_rate DECIMAL(5,2);

    IF NEW.status <> 'PENDING' OR NEW.reviewed_by_account_id IS NOT NULL
       OR NEW.reviewed_at IS NOT NULL OR NEW.closing_date IS NOT NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'A sale must be submitted as PENDING without review or closing details';
    END IF;
    IF NEW.contract_date > CURRENT_DATE THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Sale contract date cannot be in the future';
    END IF;

    SELECT p.status, p.listing_type, p.agent_id, a.commission_rate
    INTO v_property_status, v_listing_type, v_assigned_agent, v_commission_rate
    FROM property p JOIN agent a ON a.person_id = p.agent_id
    WHERE p.property_id = NEW.property_id FOR UPDATE;
    IF v_property_status <> 'AVAILABLE' OR v_listing_type <> 'FOR_SALE' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'A sale requires an AVAILABLE property listed FOR SALE';
    ELSEIF NOT EXISTS (SELECT 1 FROM tenant WHERE person_id = NEW.buyer_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Sale buyer must have a Tenant/Buyer profile';
    ELSEIF NEW.agent_id <> v_assigned_agent THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Sale agent must match the property assignment';
    ELSEIF NEW.commission_rate_at_sale <> v_commission_rate THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Commission rate must match the assigned Agent rate at submission';
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_sale_guard_update$$
CREATE TRIGGER trg_sale_guard_update
BEFORE UPDATE ON sale_transaction
FOR EACH ROW
BEGIN
    DECLARE v_property_status VARCHAR(30);
    DECLARE v_listing_type VARCHAR(20);
    DECLARE v_assigned_agent BIGINT UNSIGNED;

    IF NEW.sale_id <> OLD.sale_id OR NEW.property_id <> OLD.property_id OR NEW.buyer_id <> OLD.buyer_id
       OR NEW.agent_id <> OLD.agent_id OR NEW.sale_price <> OLD.sale_price
       OR NEW.commission_rate_at_sale <> OLD.commission_rate_at_sale
       OR NEW.contract_date <> OLD.contract_date THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Sale terms and parties are immutable after submission';
    END IF;

    IF NEW.status = OLD.status THEN
        IF NOT (NEW.closing_date <=> OLD.closing_date)
           OR NOT (NEW.reviewed_by_account_id <=> OLD.reviewed_by_account_id)
           OR NOT (NEW.reviewed_at <=> OLD.reviewed_at) THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Sale review details change only during Admin review';
        END IF;
    ELSE
        IF NOT (
            (OLD.status = 'PENDING' AND NEW.status IN ('APPROVED', 'REJECTED', 'CANCELLED'))
            OR (OLD.status = 'APPROVED' AND NEW.status IN ('CLOSED', 'CANCELLED'))
        ) THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid sale status transition';
        END IF;

        IF NEW.reviewed_by_account_id IS NULL OR NEW.reviewed_at IS NULL OR NOT EXISTS (
            SELECT 1 FROM user_account
            WHERE account_id = NEW.reviewed_by_account_id
              AND actor_role = 'ADMIN' AND is_active = TRUE
        ) THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Sale review requires an active Admin account and timestamp';
        END IF;

        IF NEW.status IN ('APPROVED', 'CLOSED') THEN
            SELECT status, listing_type, agent_id
            INTO v_property_status, v_listing_type, v_assigned_agent
            FROM property WHERE property_id = NEW.property_id FOR UPDATE;
            IF v_property_status <> 'AVAILABLE' OR v_listing_type <> 'FOR_SALE'
               OR v_assigned_agent <> NEW.agent_id THEN
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Property is no longer eligible for sale approval or closing';
            END IF;
        END IF;

        IF NEW.status = 'CLOSED' THEN
            IF NEW.closing_date IS NULL OR NEW.closing_date < NEW.contract_date
               OR NEW.closing_date > CURRENT_DATE THEN
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Closing date must be between contract date and today';
            END IF;
        ELSEIF NEW.closing_date IS NOT NULL THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Only a CLOSED sale may have a closing date';
        END IF;
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_sale_sync_insert$$
CREATE TRIGGER trg_sale_sync_insert
AFTER INSERT ON sale_transaction
FOR EACH ROW
BEGIN
    INSERT IGNORE INTO notification(account_id, notification_type, dedupe_key, title, message, sale_id)
    SELECT ua.account_id, 'SALE_UPDATE', CONCAT('sale:', NEW.sale_id, ':PENDING'),
           'Sale submitted for review',
           CONCAT('Sale #', NEW.sale_id, ' for property #', NEW.property_id, ' was submitted for review.'),
           NEW.sale_id
    FROM user_account ua
    WHERE ua.is_active = TRUE AND (
        ua.actor_role = 'ADMIN' OR ua.person_id IN (NEW.agent_id, NEW.buyer_id)
        OR ua.person_id = (SELECT owner_id FROM property WHERE property_id = NEW.property_id)
    );
END$$

DROP TRIGGER IF EXISTS trg_sale_sync_update$$
CREATE TRIGGER trg_sale_sync_update
AFTER UPDATE ON sale_transaction
FOR EACH ROW
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SET @reims_property_sync = NULL;
        RESIGNAL;
    END;
    IF OLD.status <> NEW.status THEN
        IF NEW.status = 'CLOSED' THEN
            SET @reims_property_sync = 1;
            UPDATE property SET status = 'SOLD' WHERE property_id = NEW.property_id;
            SET @reims_property_sync = NULL;
        END IF;

        INSERT IGNORE INTO notification(account_id, notification_type, dedupe_key, title, message, sale_id)
        SELECT ua.account_id, 'SALE_UPDATE', CONCAT('sale:', NEW.sale_id, ':', NEW.status),
               CONCAT('Sale ', LOWER(NEW.status)),
               CONCAT('Sale #', NEW.sale_id, ' for property #', NEW.property_id, ' is now ', LOWER(NEW.status), '.'),
               NEW.sale_id
        FROM user_account ua
        WHERE ua.is_active = TRUE AND (
            ua.actor_role = 'ADMIN' OR ua.person_id IN (NEW.agent_id, NEW.buyer_id)
            OR ua.person_id = (SELECT owner_id FROM property WHERE property_id = NEW.property_id)
        );
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_sale_no_delete$$
CREATE TRIGGER trg_sale_no_delete
BEFORE DELETE ON sale_transaction
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Sale history cannot be deleted';
END$$
DELIMITER ;
