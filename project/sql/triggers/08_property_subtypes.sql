-- A subtype row must match the parent property type; prevent both subtype rows.
USE reims_db;
DELIMITER $$

DROP TRIGGER IF EXISTS trg_residential_guard_insert$$
CREATE TRIGGER trg_residential_guard_insert
BEFORE INSERT ON residential_property
FOR EACH ROW
BEGIN
    IF NOT EXISTS (SELECT 1 FROM property WHERE property_id = NEW.property_id AND property_type = 'RESIDENTIAL')
       OR EXISTS (SELECT 1 FROM commercial_property WHERE property_id = NEW.property_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Residential details require a RESIDENTIAL parent without a commercial subtype';
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_residential_guard_update$$
CREATE TRIGGER trg_residential_guard_update
BEFORE UPDATE ON residential_property
FOR EACH ROW
BEGIN
    IF NEW.property_id <> OLD.property_id
       OR NOT EXISTS (SELECT 1 FROM property WHERE property_id = NEW.property_id AND property_type = 'RESIDENTIAL')
       OR EXISTS (SELECT 1 FROM commercial_property WHERE property_id = NEW.property_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Residential subtype must remain attached to a RESIDENTIAL property';
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_residential_no_delete$$
CREATE TRIGGER trg_residential_no_delete
BEFORE DELETE ON residential_property
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Property subtype records cannot be deleted directly';
END$$

DROP TRIGGER IF EXISTS trg_commercial_guard_insert$$
CREATE TRIGGER trg_commercial_guard_insert
BEFORE INSERT ON commercial_property
FOR EACH ROW
BEGIN
    IF NOT EXISTS (SELECT 1 FROM property WHERE property_id = NEW.property_id AND property_type = 'COMMERCIAL')
       OR EXISTS (SELECT 1 FROM residential_property WHERE property_id = NEW.property_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Commercial details require a COMMERCIAL parent without a residential subtype';
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_commercial_guard_update$$
CREATE TRIGGER trg_commercial_guard_update
BEFORE UPDATE ON commercial_property
FOR EACH ROW
BEGIN
    IF NEW.property_id <> OLD.property_id
       OR NOT EXISTS (SELECT 1 FROM property WHERE property_id = NEW.property_id AND property_type = 'COMMERCIAL')
       OR EXISTS (SELECT 1 FROM residential_property WHERE property_id = NEW.property_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Commercial subtype must remain attached to a COMMERCIAL property';
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_commercial_no_delete$$
CREATE TRIGGER trg_commercial_no_delete
BEFORE DELETE ON commercial_property
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Property subtype records cannot be deleted directly';
END$$
DELIMITER ;
