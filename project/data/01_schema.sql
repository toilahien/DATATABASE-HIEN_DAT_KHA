-- REIMS - compact MySQL 8 schema (10 business tables + account access control)
-- Run this file first. Re-running drops and recreates the project database objects.
CREATE DATABASE IF NOT EXISTS reims_db CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE reims_db;

SET FOREIGN_KEY_CHECKS = 0;
DROP VIEW IF EXISTS v_property_dashboard;
DROP VIEW IF EXISTS v_overdue_invoices;
DROP TABLE IF EXISTS property_status_history;
DROP TABLE IF EXISTS sale_transaction;
DROP TABLE IF EXISTS rental_invoice;
DROP TABLE IF EXISTS maintenance_request;
DROP TABLE IF EXISTS payment;
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
    status ENUM('AVAILABLE','LEASED','UNDER_MAINTENANCE') NOT NULL DEFAULT 'AVAILABLE',
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

CREATE TABLE payment (
    payment_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    lease_id BIGINT UNSIGNED NOT NULL,
    payment_date DATE NOT NULL,
    amount DECIMAL(15,2) NOT NULL,
    payment_type ENUM('RENT','DEPOSIT','FEE','REFUND') NOT NULL DEFAULT 'RENT',
    payment_method ENUM('CASH','BANK_TRANSFER','CARD','E_WALLET','OTHER') NULL,
    reference_code VARCHAR(80) NULL UNIQUE,
    status ENUM('POSTED','REVERSED') NOT NULL DEFAULT 'POSTED',
    notes VARCHAR(255),
    CONSTRAINT chk_payment_amount CHECK (amount > 0),
    CONSTRAINT fk_payment_lease FOREIGN KEY (lease_id) REFERENCES lease(lease_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    INDEX ix_payment_date (payment_date),
    INDEX ix_payment_lease (lease_id)
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

CREATE VIEW v_property_dashboard AS
SELECT p.property_id, p.title, p.address, p.property_type, p.listing_type,
       p.asking_price, p.status, op.full_name AS owner_name, ap.full_name AS agent_name,
       (SELECT COUNT(*) FROM lease l WHERE l.property_id = p.property_id AND l.status = 'ACTIVE') AS active_lease_count
FROM property p
JOIN owner o ON o.person_id = p.owner_id JOIN person op ON op.person_id = o.person_id
JOIN agent a ON a.person_id = p.agent_id JOIN person ap ON ap.person_id = a.person_id;
