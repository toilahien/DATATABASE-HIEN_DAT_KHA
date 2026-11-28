-- Validated entry points for changing listing mode or assigned Agent.
USE reims_db;
DELIMITER $$

DROP PROCEDURE IF EXISTS sp_update_property_listing$$
CREATE PROCEDURE sp_update_property_listing(
    IN p_property_id BIGINT UNSIGNED,
    IN p_listing_type VARCHAR(20),
    IN p_asking_price DECIMAL(15,2)
)
BEGIN
    DECLARE v_listing_type VARCHAR(20);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SET @reims_property_admin_update = NULL;
        RESIGNAL;
    END;

    IF p_listing_type NOT IN ('FOR_SALE', 'FOR_RENT') OR p_asking_price <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Choose a valid listing type and a positive asking price';
    END IF;

    SELECT listing_type INTO v_listing_type
    FROM property WHERE property_id = p_property_id FOR UPDATE;
    IF v_listing_type <> p_listing_type AND (
        EXISTS (SELECT 1 FROM lease WHERE property_id = p_property_id AND status IN ('PENDING', 'ACTIVE'))
        OR EXISTS (SELECT 1 FROM sale_transaction WHERE property_id = p_property_id AND status IN ('PENDING', 'APPROVED', 'CLOSED'))
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Listing type cannot change while a lease or sale is open or recorded';
    END IF;

    SET @reims_property_admin_update = 1;
    UPDATE property SET listing_type = p_listing_type, asking_price = p_asking_price
    WHERE property_id = p_property_id;
    SET @reims_property_admin_update = NULL;
END$$

DROP PROCEDURE IF EXISTS sp_reassign_property_agent$$
CREATE PROCEDURE sp_reassign_property_agent(
    IN p_property_id BIGINT UNSIGNED,
    IN p_agent_id BIGINT UNSIGNED
)
BEGIN
    DECLARE v_current_agent_id BIGINT UNSIGNED;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SET @reims_property_admin_update = NULL;
        RESIGNAL;
    END;

    IF NOT EXISTS (SELECT 1 FROM agent WHERE person_id = p_agent_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'The selected Agent profile does not exist';
    END IF;
    SELECT agent_id INTO v_current_agent_id
    FROM property WHERE property_id = p_property_id FOR UPDATE;
    IF v_current_agent_id <> p_agent_id AND (
        EXISTS (SELECT 1 FROM lease WHERE property_id = p_property_id AND status IN ('PENDING', 'ACTIVE'))
        OR EXISTS (SELECT 1 FROM sale_transaction WHERE property_id = p_property_id AND status IN ('PENDING', 'APPROVED', 'CLOSED'))
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Agent assignment cannot change while a lease or sale is open or recorded';
    END IF;

    SET @reims_property_admin_update = 1;
    UPDATE property SET agent_id = p_agent_id WHERE property_id = p_property_id;
    SET @reims_property_admin_update = NULL;
END$$
DELIMITER ;
