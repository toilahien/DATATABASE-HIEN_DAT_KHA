-- Property lifecycle is derived from leases, maintenance, and completed sales.
USE reims_db;
DELIMITER $$

DROP TRIGGER IF EXISTS trg_property_guard_insert$$
CREATE TRIGGER trg_property_guard_insert
BEFORE INSERT ON property
FOR EACH ROW
BEGIN
    IF NEW.status <> 'AVAILABLE' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'New properties must start as AVAILABLE';
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_property_guard_update$$
CREATE TRIGGER trg_property_guard_update
BEFORE UPDATE ON property
FOR EACH ROW
BEGIN
    IF NEW.property_type <> OLD.property_type THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Property type cannot be changed after creation';
    END IF;

    IF (NEW.listing_type <> OLD.listing_type OR NEW.owner_id <> OLD.owner_id OR NEW.agent_id <> OLD.agent_id)
       AND COALESCE(@reims_property_admin_update, 0) <> 1 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Listing, Owner, and Agent changes must use the validated property procedures';
    END IF;

    IF NEW.status <> OLD.status AND COALESCE(@reims_property_sync, 0) <> 1 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Property status is managed by approved lease, sale, and maintenance workflows';
    END IF;
END$$
DELIMITER ;
