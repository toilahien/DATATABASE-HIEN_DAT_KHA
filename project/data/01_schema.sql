-- REIMS - MySQL 8 schema: core records, rental ledger, sale transactions, and notifications.
-- Run this file first. Re-running drops and recreates the project database objects.
CREATE DATABASE IF NOT EXISTS reims_db CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE reims_db;

SET FOREIGN_KEY_CHECKS = 0;
DROP VIEW IF EXISTS v_property_dashboard;
DROP VIEW IF EXISTS v_overdue_invoices;
DROP VIEW IF EXISTS v_invoice_balance;
DROP TABLE IF EXISTS notification;
DROP TABLE IF EXISTS property_status_history;
DROP TABLE IF EXISTS sale_transaction;
DROP TABLE IF EXISTS payment;
DROP TABLE IF EXISTS rental_invoice;
DROP TABLE IF EXISTS maintenance_request;
DROP TABLE IF EXISTS lease;
DROP TABLE IF EXISTS commercial_property;
DROP TABLE IF EXISTS residential_property;
DROP TABLE IF EXISTS property;
DROP TABLE IF EXISTS tenant;
DROP TABLE IF EXISTS agent;
DROP TABLE IF EXISTS owner;
DROP TABLE IF EXISTS user_account;
DROP TABLE IF EXISTS person;
SET FOREIGN_KEY_CHECKS = 1;

CREATE TABLE person (
    person_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    full_name VARCHAR(100) NOT NULL,
    phone VARCHAR(20),
    email VARCHAR(150) UNIQUE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- Login identities are kept separate from business roles. Admin accounts have no person row;
-- Agent, Owner, and Tenant/Buyer accounts are linked to one person record.
CREATE TABLE user_account (
    account_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(80) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    actor_role ENUM('ADMIN','AGENT','OWNER','TENANT_BUYER') NOT NULL,
    person_id BIGINT UNSIGNED NULL UNIQUE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_account_person FOREIGN KEY (person_id) REFERENCES person(person_id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE owner (
    person_id BIGINT UNSIGNED PRIMARY KEY,
    mailing_address VARCHAR(255) NOT NULL,
    CONSTRAINT fk_owner_person FOREIGN KEY (person_id) REFERENCES person(person_id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE tenant (
    person_id BIGINT UNSIGNED PRIMARY KEY,
    id_card_number VARCHAR(30) NOT NULL UNIQUE,
    CONSTRAINT fk_tenant_person FOREIGN KEY (person_id) REFERENCES person(person_id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE agent (
    person_id BIGINT UNSIGNED PRIMARY KEY,
    commission_rate DECIMAL(5,2) NOT NULL,
    CONSTRAINT chk_agent_commission CHECK (commission_rate BETWEEN 0 AND 100),
    CONSTRAINT fk_agent_person FOREIGN KEY (person_id) REFERENCES person(person_id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE property (
    property_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(150) NOT NULL,
    address VARCHAR(255) NOT NULL,
    property_type ENUM('RESIDENTIAL','COMMERCIAL') NOT NULL,
    listing_type ENUM('FOR_SALE','FOR_RENT') NOT NULL,
    asking_price DECIMAL(15,2) NOT NULL,
    status ENUM('AVAILABLE','LEASED','UNDER_MAINTENANCE','SOLD') NOT NULL DEFAULT 'AVAILABLE',
    owner_id BIGINT UNSIGNED NOT NULL,
    agent_id BIGINT UNSIGNED NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_property_price CHECK (asking_price > 0),
    CONSTRAINT fk_property_owner FOREIGN KEY (owner_id) REFERENCES owner(person_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_property_agent FOREIGN KEY (agent_id) REFERENCES agent(person_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    INDEX ix_property_search (listing_type, status, asking_price),
    INDEX ix_property_owner (owner_id),
    INDEX ix_property_agent (agent_id)
) ENGINE=InnoDB;

CREATE TABLE residential_property (
    property_id BIGINT UNSIGNED PRIMARY KEY,
    bedrooms TINYINT UNSIGNED NOT NULL,
    bathrooms TINYINT UNSIGNED NOT NULL,
    area_sqm DECIMAL(10,2) NOT NULL,
    furnished_status ENUM('FURNISHED','PARTLY_FURNISHED','UNFURNISHED') NULL,
    CONSTRAINT chk_residential_area CHECK (area_sqm > 0),
    CONSTRAINT fk_residential_property FOREIGN KEY (property_id) REFERENCES property(property_id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE commercial_property (
    property_id BIGINT UNSIGNED PRIMARY KEY,
    business_type VARCHAR(60),
    floor_area_sqm DECIMAL(10,2) NOT NULL,
    parking_spaces SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    CONSTRAINT chk_commercial_area CHECK (floor_area_sqm > 0),
    CONSTRAINT fk_commercial_property FOREIGN KEY (property_id) REFERENCES property(property_id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE lease (
    lease_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    monthly_rent DECIMAL(15,2) NOT NULL,
    deposit_amount DECIMAL(15,2) NOT NULL DEFAULT 0,
    payment_day TINYINT UNSIGNED NOT NULL DEFAULT 1,
    status ENUM('PENDING','ACTIVE','EXPIRED','TERMINATED','REJECTED') NOT NULL DEFAULT 'PENDING',
    property_id BIGINT UNSIGNED NOT NULL,
    tenant_id BIGINT UNSIGNED NOT NULL,
    agent_id BIGINT UNSIGNED NOT NULL,
    reviewed_by_account_id BIGINT UNSIGNED NULL,
    reviewed_at DATETIME NULL,
    active_property_id BIGINT UNSIGNED GENERATED ALWAYS AS (CASE WHEN status = 'ACTIVE' THEN property_id ELSE NULL END) STORED,
    CONSTRAINT chk_lease_dates CHECK (end_date > start_date),
    CONSTRAINT chk_lease_rent CHECK (monthly_rent > 0),
    CONSTRAINT chk_lease_deposit CHECK (deposit_amount >= 0),
    CONSTRAINT chk_payment_day CHECK (payment_day BETWEEN 1 AND 28),
    CONSTRAINT uq_one_active_lease_per_property UNIQUE (active_property_id),
    CONSTRAINT fk_lease_property FOREIGN KEY (property_id) REFERENCES property(property_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_lease_tenant FOREIGN KEY (tenant_id) REFERENCES tenant(person_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_lease_agent FOREIGN KEY (agent_id) REFERENCES agent(person_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_lease_reviewer FOREIGN KEY (reviewed_by_account_id) REFERENCES user_account(account_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    INDEX ix_lease_dates_status (status, start_date, end_date),
    INDEX ix_lease_tenant (tenant_id)
) ENGINE=InnoDB;

CREATE TABLE rental_invoice (
    invoice_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    lease_id BIGINT UNSIGNED NOT NULL,
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    issue_date DATE NOT NULL,
    due_date DATE NOT NULL,
    amount_due DECIMAL(15,2) NOT NULL,
    status ENUM('ISSUED','VOID') NOT NULL DEFAULT 'ISSUED',
    CONSTRAINT chk_invoice_period CHECK (period_end >= period_start),
    CONSTRAINT chk_invoice_due CHECK (due_date >= period_start),
    CONSTRAINT chk_invoice_amount CHECK (amount_due > 0),
    CONSTRAINT uq_invoice_lease_period UNIQUE (lease_id, period_start),
    CONSTRAINT fk_invoice_lease FOREIGN KEY (lease_id) REFERENCES lease(lease_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    INDEX ix_invoice_due (status, due_date),
    INDEX ix_invoice_lease (lease_id)
) ENGINE=InnoDB;

CREATE TABLE payment (
    payment_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    lease_id BIGINT UNSIGNED NOT NULL,
    invoice_id BIGINT UNSIGNED NULL,
    payment_date DATE NOT NULL,
    amount DECIMAL(15,2) NOT NULL,
    payment_type ENUM('RENT','DEPOSIT','FEE','REFUND') NOT NULL DEFAULT 'RENT',
    payment_method ENUM('CASH','BANK_TRANSFER','CARD','E_WALLET','OTHER') NULL,
    reference_code VARCHAR(80) NULL UNIQUE,
    idempotency_key CHAR(36) NOT NULL UNIQUE,
    status ENUM('POSTED','REVERSED') NOT NULL DEFAULT 'POSTED',
    notes VARCHAR(255),
    CONSTRAINT chk_payment_amount CHECK (amount > 0),
    CONSTRAINT fk_payment_lease FOREIGN KEY (lease_id) REFERENCES lease(lease_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_payment_invoice FOREIGN KEY (invoice_id) REFERENCES rental_invoice(invoice_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    INDEX ix_payment_date (payment_date),
    INDEX ix_payment_lease (lease_id),
    INDEX ix_payment_invoice (invoice_id)
) ENGINE=InnoDB;

CREATE TABLE sale_transaction (
    sale_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    property_id BIGINT UNSIGNED NOT NULL,
    buyer_id BIGINT UNSIGNED NOT NULL,
    agent_id BIGINT UNSIGNED NOT NULL,
    sale_price DECIMAL(15,2) NOT NULL,
    commission_rate_at_sale DECIMAL(5,2) NOT NULL,
    status ENUM('PENDING','APPROVED','CLOSED','REJECTED','CANCELLED') NOT NULL DEFAULT 'PENDING',
    commission_amount DECIMAL(15,2) GENERATED ALWAYS AS
        (CASE WHEN status='CLOSED' THEN ROUND(sale_price * commission_rate_at_sale / 100, 2) ELSE 0 END) STORED,
    contract_date DATE NOT NULL,
    closing_date DATE NULL,
    reviewed_by_account_id BIGINT UNSIGNED NULL,
    reviewed_at DATETIME NULL,
    active_property_id BIGINT UNSIGNED GENERATED ALWAYS AS
        (CASE WHEN status IN ('PENDING','APPROVED') THEN property_id ELSE NULL END) STORED,
    CONSTRAINT chk_sale_price CHECK (sale_price > 0),
    CONSTRAINT chk_sale_commission_rate CHECK (commission_rate_at_sale BETWEEN 0 AND 100),
    CONSTRAINT chk_sale_closing_date CHECK (status <> 'CLOSED' OR closing_date IS NOT NULL),
    CONSTRAINT uq_sale_open_property UNIQUE (active_property_id),
    CONSTRAINT fk_sale_property FOREIGN KEY (property_id) REFERENCES property(property_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_sale_buyer FOREIGN KEY (buyer_id) REFERENCES person(person_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_sale_agent FOREIGN KEY (agent_id) REFERENCES agent(person_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_sale_reviewer FOREIGN KEY (reviewed_by_account_id) REFERENCES user_account(account_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    INDEX ix_sale_status_date (status, contract_date),
    INDEX ix_sale_agent (agent_id)
) ENGINE=InnoDB;

CREATE TABLE notification (
    notification_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    account_id BIGINT UNSIGNED NOT NULL,
    notification_type ENUM('INVOICE_DUE','INVOICE_OVERDUE','LEASE_EXPIRING','LEASE_EXPIRED','SALE_UPDATE','SYSTEM') NOT NULL,
    dedupe_key VARCHAR(160) NOT NULL,
    title VARCHAR(150) NOT NULL,
    message VARCHAR(500) NOT NULL,
    invoice_id BIGINT UNSIGNED NULL,
    sale_id BIGINT UNSIGNED NULL,
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_notification_dedupe UNIQUE (account_id, dedupe_key),
    CONSTRAINT fk_notification_account FOREIGN KEY (account_id) REFERENCES user_account(account_id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_notification_invoice FOREIGN KEY (invoice_id) REFERENCES rental_invoice(invoice_id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_notification_sale FOREIGN KEY (sale_id) REFERENCES sale_transaction(sale_id) ON DELETE CASCADE ON UPDATE CASCADE,
    INDEX ix_notification_unread (account_id, is_read, created_at)
) ENGINE=InnoDB;

CREATE TABLE maintenance_request (
    request_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    lease_id BIGINT UNSIGNED NOT NULL,
    description TEXT NOT NULL,
    report_date DATE NOT NULL,
    estimated_cost DECIMAL(15,2) NULL,
    actual_cost DECIMAL(15,2) NULL,
    status ENUM('PENDING','IN_PROGRESS','COMPLETED','CANCELLED') NOT NULL DEFAULT 'PENDING',
    resolved_at DATETIME NULL,
    CONSTRAINT chk_maintenance_estimate CHECK (estimated_cost IS NULL OR estimated_cost >= 0),
    CONSTRAINT chk_maintenance_actual CHECK (actual_cost IS NULL OR actual_cost >= 0),
    CONSTRAINT fk_maintenance_lease FOREIGN KEY (lease_id) REFERENCES lease(lease_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    INDEX ix_maintenance_status (status, report_date),
    INDEX ix_maintenance_lease (lease_id)
) ENGINE=InnoDB;

DELIMITER $$
CREATE TRIGGER trg_account_role_insert
BEFORE INSERT ON user_account
FOR EACH ROW
BEGIN
    IF (NEW.actor_role = 'ADMIN' AND NEW.person_id IS NOT NULL) OR
       (NEW.actor_role <> 'ADMIN' AND NEW.person_id IS NULL) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Admin accounts must not link a person; other accounts must link one';
    ELSEIF NEW.actor_role = 'AGENT' AND NOT EXISTS (SELECT 1 FROM agent WHERE person_id = NEW.person_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Agent account must link to an Agent profile';
    ELSEIF NEW.actor_role = 'OWNER' AND NOT EXISTS (SELECT 1 FROM owner WHERE person_id = NEW.person_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Owner account must link to an Owner profile';
    ELSEIF NEW.actor_role = 'TENANT_BUYER' AND (
        EXISTS (SELECT 1 FROM owner WHERE person_id = NEW.person_id) OR
        EXISTS (SELECT 1 FROM agent WHERE person_id = NEW.person_id)
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Tenant/Buyer account cannot link to an Owner or Agent profile';
    END IF;
END$$

CREATE TRIGGER trg_account_role_update
BEFORE UPDATE ON user_account
FOR EACH ROW
BEGIN
    IF (NEW.actor_role = 'ADMIN' AND NEW.person_id IS NOT NULL) OR
       (NEW.actor_role <> 'ADMIN' AND NEW.person_id IS NULL) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Admin accounts must not link a person; other accounts must link one';
    ELSEIF NEW.actor_role = 'AGENT' AND NOT EXISTS (SELECT 1 FROM agent WHERE person_id = NEW.person_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Agent account must link to an Agent profile';
    ELSEIF NEW.actor_role = 'OWNER' AND NOT EXISTS (SELECT 1 FROM owner WHERE person_id = NEW.person_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Owner account must link to an Owner profile';
    ELSEIF NEW.actor_role = 'TENANT_BUYER' AND (
        EXISTS (SELECT 1 FROM owner WHERE person_id = NEW.person_id) OR
        EXISTS (SELECT 1 FROM agent WHERE person_id = NEW.person_id)
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Tenant/Buyer account cannot link to an Owner or Agent profile';
    END IF;
END$$

CREATE TRIGGER trg_lease_guard_insert
BEFORE INSERT ON lease
FOR EACH ROW
BEGIN
    DECLARE v_property_status VARCHAR(30);
    DECLARE v_listing_type VARCHAR(20);
    IF NEW.status = 'ACTIVE' THEN
        SELECT status, listing_type INTO v_property_status, v_listing_type
        FROM property WHERE property_id = NEW.property_id FOR UPDATE;
        IF v_property_status <> 'AVAILABLE' OR v_listing_type <> 'FOR_RENT' THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'An active lease requires an AVAILABLE rental property';
        END IF;
    END IF;
END$$

CREATE TRIGGER trg_lease_guard_update
BEFORE UPDATE ON lease
FOR EACH ROW
BEGIN
    DECLARE v_property_status VARCHAR(30);
    DECLARE v_listing_type VARCHAR(20);
    IF OLD.status = 'ACTIVE' AND NEW.property_id <> OLD.property_id THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'An active lease cannot be moved to another property';
    END IF;
    IF NEW.status = 'ACTIVE' AND OLD.status <> 'ACTIVE' THEN
        SELECT status, listing_type INTO v_property_status, v_listing_type
        FROM property WHERE property_id = NEW.property_id FOR UPDATE;
        IF v_property_status <> 'AVAILABLE' OR v_listing_type <> 'FOR_RENT' THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'An active lease requires an AVAILABLE rental property';
        END IF;
    END IF;
END$$

CREATE TRIGGER trg_lease_sync_insert
AFTER INSERT ON lease
FOR EACH ROW
BEGIN
    IF NEW.status = 'ACTIVE' THEN
        UPDATE property SET status = 'LEASED' WHERE property_id = NEW.property_id;
    END IF;
END$$

CREATE TRIGGER trg_lease_sync_update
AFTER UPDATE ON lease
FOR EACH ROW
BEGIN
    IF OLD.status <> NEW.status THEN
        IF NEW.status = 'ACTIVE' THEN
            UPDATE property SET status = 'LEASED' WHERE property_id = NEW.property_id;
        ELSEIF OLD.status = 'ACTIVE' AND NEW.status <> 'ACTIVE' THEN
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
        END IF;
    END IF;
END$$

CREATE TRIGGER trg_payment_invoice_guard
BEFORE INSERT ON payment
FOR EACH ROW
BEGIN
    DECLARE v_invoice_lease BIGINT UNSIGNED;
    IF NEW.payment_type='RENT' AND NEW.invoice_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Rent payments must be linked to a rental invoice';
    END IF;
    IF NEW.invoice_id IS NOT NULL THEN
        SELECT MAX(lease_id) INTO v_invoice_lease FROM rental_invoice
        WHERE invoice_id=NEW.invoice_id AND status='ISSUED';
        IF v_invoice_lease IS NULL OR v_invoice_lease<>NEW.lease_id THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Payment invoice must belong to the selected lease';
        END IF;
        IF NEW.payment_type NOT IN ('RENT','REFUND') THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Only rent payments or refunds can reference an invoice';
        END IF;
    END IF;
END$$

CREATE TRIGGER trg_sale_guard_insert
BEFORE INSERT ON sale_transaction
FOR EACH ROW
BEGIN
    DECLARE v_property_status VARCHAR(30);
    DECLARE v_listing_type VARCHAR(20);
    DECLARE v_assigned_agent BIGINT UNSIGNED;
    SELECT status,listing_type,agent_id INTO v_property_status,v_listing_type,v_assigned_agent
    FROM property WHERE property_id=NEW.property_id FOR UPDATE;
    IF v_property_status<>'AVAILABLE' OR v_listing_type<>'FOR_SALE' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='A sale requires an AVAILABLE property listed FOR SALE';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM tenant WHERE person_id=NEW.buyer_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Sale buyer must have a Tenant/Buyer profile';
    END IF;
    IF NEW.agent_id<>v_assigned_agent THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Sale agent must match the property assignment';
    END IF;
END$$

CREATE TRIGGER trg_sale_guard_update
BEFORE UPDATE ON sale_transaction
FOR EACH ROW
BEGIN
    IF OLD.status='CLOSED' AND NEW.status<>'CLOSED' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='A closed sale is immutable';
    ELSEIF OLD.status='PENDING' AND NEW.status NOT IN ('PENDING','APPROVED','REJECTED','CANCELLED') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Invalid sale status transition';
    ELSEIF OLD.status='APPROVED' AND NEW.status NOT IN ('APPROVED','CLOSED','CANCELLED') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Invalid sale status transition';
    ELSEIF OLD.status IN ('REJECTED','CANCELLED') AND NEW.status<>OLD.status THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Rejected or cancelled sales cannot be reopened';
    END IF;
END$$

CREATE TRIGGER trg_sale_sync_insert
AFTER INSERT ON sale_transaction
FOR EACH ROW
BEGIN
    IF NEW.status='CLOSED' THEN
        UPDATE property SET status='SOLD' WHERE property_id=NEW.property_id;
    END IF;
    INSERT IGNORE INTO notification(account_id,notification_type,dedupe_key,title,message,sale_id)
    SELECT ua.account_id,'SALE_UPDATE',CONCAT('sale:',NEW.sale_id,':',NEW.status),
           CONCAT('Sale ',LOWER(NEW.status)),
           CONCAT('Sale #',NEW.sale_id,' for property #',NEW.property_id,' is now ',LOWER(NEW.status),'.'),
           NEW.sale_id
    FROM user_account ua
    WHERE ua.actor_role='ADMIN'
       OR ua.person_id IN (NEW.agent_id,NEW.buyer_id)
       OR ua.person_id=(SELECT owner_id FROM property WHERE property_id=NEW.property_id);
END$$

CREATE TRIGGER trg_sale_sync_update
AFTER UPDATE ON sale_transaction
FOR EACH ROW
BEGIN
    IF OLD.status<>'CLOSED' AND NEW.status='CLOSED' THEN
        UPDATE property SET status='SOLD' WHERE property_id=NEW.property_id;
    END IF;
    IF OLD.status<>NEW.status THEN
        INSERT IGNORE INTO notification(account_id,notification_type,dedupe_key,title,message,sale_id)
        SELECT ua.account_id,'SALE_UPDATE',CONCAT('sale:',NEW.sale_id,':',NEW.status),
               CONCAT('Sale ',LOWER(NEW.status)),
               CONCAT('Sale #',NEW.sale_id,' for property #',NEW.property_id,' is now ',LOWER(NEW.status),'.'),
               NEW.sale_id
        FROM user_account ua
        WHERE ua.actor_role='ADMIN'
           OR ua.person_id IN (NEW.agent_id,NEW.buyer_id)
           OR ua.person_id=(SELECT owner_id FROM property WHERE property_id=NEW.property_id);
    END IF;
END$$

CREATE TRIGGER trg_maintenance_guard_insert
BEFORE INSERT ON maintenance_request
FOR EACH ROW
BEGIN
    IF NOT EXISTS (SELECT 1 FROM lease WHERE lease_id = NEW.lease_id AND status = 'ACTIVE') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'A maintenance request requires an active lease';
    END IF;
END$$

CREATE TRIGGER trg_maintenance_guard_update
BEFORE UPDATE ON maintenance_request
FOR EACH ROW
BEGIN
    IF NEW.status IN ('PENDING','IN_PROGRESS') AND NOT EXISTS (
        SELECT 1 FROM lease WHERE lease_id = NEW.lease_id AND status = 'ACTIVE'
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Open maintenance work requires an active lease';
    END IF;
END$$

CREATE TRIGGER trg_maintenance_sync_insert
AFTER INSERT ON maintenance_request
FOR EACH ROW
BEGIN
    DECLARE v_property_id BIGINT UNSIGNED;
    IF NEW.status = 'IN_PROGRESS' THEN
        SELECT property_id INTO v_property_id FROM lease WHERE lease_id = NEW.lease_id;
        UPDATE property SET status = 'UNDER_MAINTENANCE' WHERE property_id = v_property_id AND status IN ('AVAILABLE','LEASED');
    END IF;
END$$

CREATE TRIGGER trg_maintenance_sync_update
AFTER UPDATE ON maintenance_request
FOR EACH ROW
BEGIN
    DECLARE v_property_id BIGINT UNSIGNED;
    IF OLD.status <> NEW.status THEN
        SELECT property_id INTO v_property_id FROM lease WHERE lease_id = NEW.lease_id;
        IF NEW.status = 'IN_PROGRESS' THEN
            UPDATE property SET status = 'UNDER_MAINTENANCE' WHERE property_id = v_property_id AND status IN ('AVAILABLE','LEASED');
        ELSEIF OLD.status = 'IN_PROGRESS' THEN
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
            WHERE p.property_id = v_property_id AND p.status = 'UNDER_MAINTENANCE';
        END IF;
    END IF;
END$$
DELIMITER ;

DELIMITER $$
DROP PROCEDURE IF EXISTS sp_generate_rental_invoices$$
CREATE PROCEDURE sp_generate_rental_invoices(IN p_as_of DATE)
BEGIN
    DECLARE v_done BOOLEAN DEFAULT FALSE;
    DECLARE v_lease_id BIGINT UNSIGNED;
    DECLARE v_start DATE;
    DECLARE v_end DATE;
    DECLARE v_rent DECIMAL(15,2);
    DECLARE v_payment_day TINYINT UNSIGNED;
    DECLARE v_month DATE;
    DECLARE v_last_month DATE;
    DECLARE v_period_start DATE;
    DECLARE v_period_end DATE;
    DECLARE v_due_date DATE;
    DECLARE lease_cursor CURSOR FOR
        SELECT lease_id,start_date,end_date,monthly_rent,payment_day
        FROM lease
        WHERE status IN ('ACTIVE','TERMINATED','EXPIRED') AND start_date<=p_as_of;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done=TRUE;

    OPEN lease_cursor;
    lease_loop: LOOP
        FETCH lease_cursor INTO v_lease_id,v_start,v_end,v_rent,v_payment_day;
        IF v_done THEN LEAVE lease_loop; END IF;
        SET v_month=STR_TO_DATE(CONCAT(YEAR(v_start),'-',LPAD(MONTH(v_start),2,'0'),'-01'),'%Y-%m-%d');
        SET v_last_month=STR_TO_DATE(CONCAT(YEAR(LEAST(v_end,p_as_of)),'-',LPAD(MONTH(LEAST(v_end,p_as_of)),2,'0'),'-01'),'%Y-%m-%d');
        WHILE v_month<=v_last_month DO
            SET v_period_start=GREATEST(v_start,v_month);
            SET v_period_end=LEAST(v_end,LAST_DAY(v_month));
            SET v_due_date=DATE_ADD(v_month,INTERVAL (LEAST(v_payment_day,DAY(LAST_DAY(v_month)))-1) DAY);
            IF v_due_date<v_period_start THEN SET v_due_date=v_period_start; END IF;
            INSERT IGNORE INTO rental_invoice(lease_id,period_start,period_end,issue_date,due_date,amount_due)
            VALUES(v_lease_id,v_period_start,v_period_end,v_period_start,v_due_date,v_rent);
            SET v_month=DATE_ADD(v_month,INTERVAL 1 MONTH);
        END WHILE;
    END LOOP;
    CLOSE lease_cursor;
END$$

DROP PROCEDURE IF EXISTS sp_refresh_notifications$$
CREATE PROCEDURE sp_refresh_notifications(IN p_as_of DATE)
BEGIN
    -- Expire leases after their contractual end date; lease triggers restore the
    -- property state while respecting any maintenance work still in progress.
    UPDATE lease SET status='EXPIRED'
    WHERE status='ACTIVE' AND end_date<p_as_of;

    UPDATE notification n
    JOIN v_invoice_balance b ON b.invoice_id=n.invoice_id
    SET n.is_read=TRUE
    WHERE n.notification_type='INVOICE_DUE'
      AND (b.invoice_status NOT IN ('DUE','PARTIALLY_PAID') OR b.due_date<p_as_of);

    UPDATE notification n
    JOIN v_invoice_balance b ON b.invoice_id=n.invoice_id
    SET n.is_read=TRUE
    WHERE n.notification_type='INVOICE_OVERDUE'
      AND b.invoice_status<>'OVERDUE';

    INSERT IGNORE INTO notification(account_id,notification_type,dedupe_key,title,message,invoice_id)
    SELECT ua.account_id,'INVOICE_DUE',CONCAT('invoice:',b.invoice_id,':due'),
           'Rent payment due soon',CONCAT('Invoice #',b.invoice_id,' is due on ',DATE_FORMAT(b.due_date,'%Y-%m-%d'),'. Balance: ',FORMAT(b.balance_due,0),' VND.'),b.invoice_id
    FROM v_invoice_balance b
    JOIN lease l ON l.lease_id=b.lease_id
    JOIN user_account ua ON ua.person_id=l.tenant_id AND ua.actor_role='TENANT_BUYER'
    WHERE b.invoice_status IN ('DUE','PARTIALLY_PAID') AND b.balance_due>0
      AND b.due_date BETWEEN p_as_of AND DATE_ADD(p_as_of,INTERVAL 7 DAY);

    INSERT IGNORE INTO notification(account_id,notification_type,dedupe_key,title,message,invoice_id)
    SELECT ua.account_id,'INVOICE_OVERDUE',CONCAT('invoice:',b.invoice_id,':overdue'),
           'Rent payment overdue',CONCAT('Invoice #',b.invoice_id,' was due on ',DATE_FORMAT(b.due_date,'%Y-%m-%d'),'. Balance: ',FORMAT(b.balance_due,0),' VND.'),b.invoice_id
    FROM v_invoice_balance b
    JOIN lease l ON l.lease_id=b.lease_id
    JOIN user_account ua ON ua.person_id=l.tenant_id AND ua.actor_role='TENANT_BUYER'
    WHERE b.invoice_status='OVERDUE' AND b.balance_due>0;

    INSERT IGNORE INTO notification(account_id,notification_type,dedupe_key,title,message,invoice_id)
    SELECT ua.account_id,'INVOICE_OVERDUE',CONCAT('admin:invoice:',b.invoice_id,':overdue'),
           'Overdue rent invoice',CONCAT('Invoice #',b.invoice_id,' for lease #',b.lease_id,' is overdue. Balance: ',FORMAT(b.balance_due,0),' VND.'),b.invoice_id
    FROM v_invoice_balance b
    JOIN user_account ua ON ua.actor_role='ADMIN'
    WHERE b.invoice_status='OVERDUE' AND b.balance_due>0;

    INSERT IGNORE INTO notification(account_id,notification_type,dedupe_key,title,message)
    SELECT ua.account_id,'LEASE_EXPIRED',CONCAT('lease:',l.lease_id,':expired'),
           'Lease has expired',CONCAT('Lease #',l.lease_id,' ended on ',DATE_FORMAT(l.end_date,'%Y-%m-%d'),'.')
    FROM lease l
    JOIN user_account ua ON ua.person_id IN (l.tenant_id,l.agent_id) OR ua.actor_role='ADMIN'
    WHERE l.status='EXPIRED' AND l.end_date<p_as_of;

    INSERT IGNORE INTO notification(account_id,notification_type,dedupe_key,title,message)
    SELECT ua.account_id,'LEASE_EXPIRING',CONCAT('lease:',l.lease_id,':expiring'),
           'Lease ending soon',CONCAT('Lease #',l.lease_id,' ends on ',DATE_FORMAT(l.end_date,'%Y-%m-%d'),'.')
    FROM lease l
    JOIN user_account ua ON ua.person_id IN (l.tenant_id,l.agent_id) OR ua.actor_role='ADMIN'
    WHERE l.status='ACTIVE' AND l.end_date BETWEEN p_as_of AND DATE_ADD(p_as_of,INTERVAL 30 DAY);
END$$
DELIMITER ;

CREATE VIEW v_property_dashboard AS
SELECT p.property_id, p.title, p.address, p.property_type, p.listing_type,
       p.asking_price, p.status, op.full_name AS owner_name, ap.full_name AS agent_name,
       (SELECT COUNT(*) FROM lease l WHERE l.property_id = p.property_id AND l.status = 'ACTIVE') AS active_lease_count
FROM property p
JOIN owner o ON o.person_id = p.owner_id JOIN person op ON op.person_id = o.person_id
JOIN agent a ON a.person_id = p.agent_id JOIN person ap ON ap.person_id = a.person_id;

CREATE VIEW v_invoice_balance AS
SELECT i.invoice_id,i.lease_id,i.period_start,i.period_end,i.issue_date,i.due_date,i.amount_due,i.status,
       COALESCE(SUM(CASE WHEN pay.status='POSTED' AND pay.payment_type='RENT' THEN pay.amount
                         WHEN pay.status='POSTED' AND pay.payment_type='REFUND' THEN -pay.amount ELSE 0 END),0) AS amount_paid,
       GREATEST(i.amount_due-COALESCE(SUM(CASE WHEN pay.status='POSTED' AND pay.payment_type='RENT' THEN pay.amount
                                               WHEN pay.status='POSTED' AND pay.payment_type='REFUND' THEN -pay.amount ELSE 0 END),0),0) AS balance_due,
       CASE WHEN i.status='VOID' THEN 'VOID'
            WHEN i.amount_due<=COALESCE(SUM(CASE WHEN pay.status='POSTED' AND pay.payment_type='RENT' THEN pay.amount
                                                 WHEN pay.status='POSTED' AND pay.payment_type='REFUND' THEN -pay.amount ELSE 0 END),0) THEN 'PAID'
            WHEN i.due_date<CURRENT_DATE THEN 'OVERDUE'
            WHEN COALESCE(SUM(CASE WHEN pay.status='POSTED' AND pay.payment_type='RENT' THEN pay.amount
                                   WHEN pay.status='POSTED' AND pay.payment_type='REFUND' THEN -pay.amount ELSE 0 END),0)>0 THEN 'PARTIALLY_PAID'
            ELSE 'DUE' END AS invoice_status
FROM rental_invoice i LEFT JOIN payment pay ON pay.invoice_id=i.invoice_id
GROUP BY i.invoice_id,i.lease_id,i.period_start,i.period_end,i.issue_date,i.due_date,i.amount_due,i.status;

CREATE VIEW v_overdue_invoices AS
SELECT b.*,l.tenant_id,l.agent_id,p.property_id,p.title
FROM v_invoice_balance b JOIN lease l ON l.lease_id=b.lease_id JOIN property p ON p.property_id=l.property_id
WHERE b.invoice_status='OVERDUE';
