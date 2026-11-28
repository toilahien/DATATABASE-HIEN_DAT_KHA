-- Maintenance requests belong to active leases and drive the property state.
USE reims_db;
DELIMITER $$

DROP TRIGGER IF EXISTS trg_maintenance_guard_insert$$
CREATE TRIGGER trg_maintenance_guard_insert
BEFORE INSERT ON maintenance_request
FOR EACH ROW
BEGIN
    IF NEW.report_date > CURRENT_DATE THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Maintenance report date cannot be in the future';
    ELSEIF NEW.status <> 'PENDING' OR NEW.resolved_at IS NOT NULL OR NEW.actual_cost IS NOT NULL
       OR NEW.reviewed_by_account_id IS NOT NULL OR NEW.reviewed_at IS NOT NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'New maintenance requests must start PENDING without resolution data';
    ELSEIF NOT EXISTS (SELECT 1 FROM lease WHERE lease_id = NEW.lease_id AND status = 'ACTIVE') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'A maintenance request requires an active lease';
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_maintenance_guard_update$$
CREATE TRIGGER trg_maintenance_guard_update
BEFORE UPDATE ON maintenance_request
FOR EACH ROW
BEGIN
    IF NEW.request_id <> OLD.request_id OR NEW.lease_id <> OLD.lease_id
       OR NEW.description <> OLD.description OR NEW.report_date <> OLD.report_date THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Maintenance request identity and reported issue are immutable';
    END IF;

    IF OLD.status = NEW.status THEN
        IF NOT (NEW.estimated_cost <=> OLD.estimated_cost)
           OR NOT (NEW.actual_cost <=> OLD.actual_cost)
           OR NOT (NEW.resolved_at <=> OLD.resolved_at)
           OR NOT (NEW.reviewed_by_account_id <=> OLD.reviewed_by_account_id)
           OR NOT (NEW.reviewed_at <=> OLD.reviewed_at) THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Maintenance review and resolution details change only during a status transition';
        END IF;
    ELSE
        IF NOT ((OLD.status = 'PENDING' AND NEW.status IN ('IN_PROGRESS', 'CANCELLED'))
                OR (OLD.status = 'IN_PROGRESS' AND NEW.status IN ('COMPLETED', 'CANCELLED'))) THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid or final maintenance status transition';
        END IF;
        IF NEW.reviewed_by_account_id IS NULL OR NEW.reviewed_at IS NULL OR NOT EXISTS (
            SELECT 1 FROM user_account
            WHERE account_id = NEW.reviewed_by_account_id
              AND actor_role = 'ADMIN' AND is_active = TRUE
        ) THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Maintenance status changes require an active Admin account and timestamp';
        END IF;
        IF OLD.status = 'PENDING' AND NEW.status = 'IN_PROGRESS' THEN
            IF NOT EXISTS (SELECT 1 FROM lease WHERE lease_id = NEW.lease_id AND status = 'ACTIVE')
               OR NEW.resolved_at IS NOT NULL OR NEW.actual_cost IS NOT NULL THEN
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Only an active lease request can enter maintenance';
            END IF;
        ELSEIF NEW.status = 'COMPLETED' THEN
            IF NEW.resolved_at IS NULL OR NEW.resolved_at > CURRENT_TIMESTAMP THEN
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Completed maintenance requires a resolution timestamp no later than now';
            END IF;
        ELSEIF NEW.status = 'CANCELLED' THEN
            IF NEW.resolved_at IS NOT NULL OR NEW.actual_cost IS NOT NULL THEN
                SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cancelled requests cannot contain completion data';
            END IF;
        END IF;
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_maintenance_sync_insert$$

DROP TRIGGER IF EXISTS trg_maintenance_sync_update$$
CREATE TRIGGER trg_maintenance_sync_update
AFTER UPDATE ON maintenance_request
FOR EACH ROW
BEGIN
    DECLARE v_property_id BIGINT UNSIGNED;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SET @reims_property_sync = NULL;
        RESIGNAL;
    END;
    IF OLD.status <> NEW.status THEN
        SELECT property_id INTO v_property_id FROM lease WHERE lease_id = NEW.lease_id;
        IF NEW.status = 'IN_PROGRESS' THEN
            SET @reims_property_sync = 1;
            UPDATE property SET status = 'UNDER_MAINTENANCE' WHERE property_id = v_property_id;
            SET @reims_property_sync = NULL;
        ELSEIF OLD.status = 'IN_PROGRESS' THEN
            SET @reims_property_sync = 1;
            UPDATE property p
            SET p.status = CASE
                WHEN EXISTS (
                    SELECT 1 FROM maintenance_request m
                    JOIN lease ml ON ml.lease_id = m.lease_id
                    WHERE ml.property_id = v_property_id
                      AND m.status = 'IN_PROGRESS' AND m.request_id <> NEW.request_id
                ) THEN 'UNDER_MAINTENANCE'
                WHEN EXISTS (SELECT 1 FROM lease l WHERE l.property_id = v_property_id AND l.status = 'ACTIVE') THEN 'LEASED'
                ELSE 'AVAILABLE'
            END
            WHERE p.property_id = v_property_id;
            SET @reims_property_sync = NULL;
        END IF;
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_maintenance_no_delete$$
CREATE TRIGGER trg_maintenance_no_delete
BEFORE DELETE ON maintenance_request
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Maintenance history cannot be deleted';
END$$
DELIMITER ;
