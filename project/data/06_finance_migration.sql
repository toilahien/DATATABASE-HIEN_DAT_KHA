-- Add rental billing, sale transactions, idempotent payments, and notifications
-- to an existing REIMS database without dropping current rows.
-- Run after 05_auth_migration.sql. Safe to re-run.
USE reims_db;

ALTER TABLE property
    MODIFY COLUMN status ENUM('AVAILABLE','LEASED','UNDER_MAINTENANCE','SOLD') NOT NULL DEFAULT 'AVAILABLE';

CREATE TABLE IF NOT EXISTS rental_invoice (
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

SET @has_payment_invoice = (
    SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='payment' AND COLUMN_NAME='invoice_id'
);
SET @payment_invoice_sql = IF(@has_payment_invoice=0,
    'ALTER TABLE payment ADD COLUMN invoice_id BIGINT UNSIGNED NULL AFTER lease_id',
    'SELECT 1');
PREPARE payment_invoice_stmt FROM @payment_invoice_sql;
EXECUTE payment_invoice_stmt;
DEALLOCATE PREPARE payment_invoice_stmt;

SET @has_payment_request_key = (
    SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='payment' AND COLUMN_NAME='idempotency_key'
);
SET @payment_request_key_sql = IF(@has_payment_request_key=0,
    'ALTER TABLE payment ADD COLUMN idempotency_key CHAR(36) NULL',
    'SELECT 1');
PREPARE payment_request_key_stmt FROM @payment_request_key_sql;
EXECUTE payment_request_key_stmt;
DEALLOCATE PREPARE payment_request_key_stmt;
UPDATE payment SET idempotency_key=UUID() WHERE idempotency_key IS NULL;
ALTER TABLE payment MODIFY COLUMN idempotency_key CHAR(36) NOT NULL;

SET @has_payment_request_key_index = (
    SELECT COUNT(*) FROM information_schema.STATISTICS
    WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='payment' AND INDEX_NAME='uq_payment_idempotency_key'
);
SET @payment_request_key_index_sql = IF(@has_payment_request_key_index=0,
    'ALTER TABLE payment ADD CONSTRAINT uq_payment_idempotency_key UNIQUE (idempotency_key)',
    'SELECT 1');
PREPARE payment_request_key_index_stmt FROM @payment_request_key_index_sql;
EXECUTE payment_request_key_index_stmt;
DEALLOCATE PREPARE payment_request_key_index_stmt;

SET @has_payment_invoice_fk = (
    SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS
    WHERE CONSTRAINT_SCHEMA=DATABASE() AND TABLE_NAME='payment'
      AND CONSTRAINT_NAME='fk_payment_invoice' AND CONSTRAINT_TYPE='FOREIGN KEY'
);
SET @payment_invoice_fk_sql = IF(@has_payment_invoice_fk=0,
    'ALTER TABLE payment ADD CONSTRAINT fk_payment_invoice FOREIGN KEY (invoice_id) REFERENCES rental_invoice(invoice_id) ON DELETE RESTRICT ON UPDATE RESTRICT',
    'SELECT 1');
PREPARE payment_invoice_fk_stmt FROM @payment_invoice_fk_sql;
EXECUTE payment_invoice_fk_stmt;
DEALLOCATE PREPARE payment_invoice_fk_stmt;

SET @has_payment_invoice_index = (
    SELECT COUNT(*) FROM information_schema.STATISTICS
    WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='payment' AND INDEX_NAME='ix_payment_invoice'
);
SET @payment_invoice_index_sql = IF(@has_payment_invoice_index=0,
    'CREATE INDEX ix_payment_invoice ON payment(invoice_id)',
    'SELECT 1');
PREPARE payment_invoice_index_stmt FROM @payment_invoice_index_sql;
EXECUTE payment_invoice_index_stmt;
DEALLOCATE PREPARE payment_invoice_index_stmt;

CREATE TABLE IF NOT EXISTS sale_transaction (
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

CREATE TABLE IF NOT EXISTS notification (
    notification_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    account_id BIGINT UNSIGNED NOT NULL,
    notification_type ENUM('INVOICE_DUE','INVOICE_OVERDUE','LEASE_EXPIRING','SALE_UPDATE','SYSTEM') NOT NULL,
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

ALTER TABLE notification
    MODIFY COLUMN notification_type ENUM('INVOICE_DUE','INVOICE_OVERDUE','LEASE_EXPIRING','LEASE_EXPIRED','SALE_UPDATE','SYSTEM') NOT NULL;

DELIMITER $$
DROP TRIGGER IF EXISTS trg_payment_invoice_guard$$
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

DROP TRIGGER IF EXISTS trg_sale_guard_insert$$
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

DROP TRIGGER IF EXISTS trg_sale_guard_update$$
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

DROP TRIGGER IF EXISTS trg_sale_sync_insert$$
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

DROP TRIGGER IF EXISTS trg_sale_sync_update$$
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
        FROM lease WHERE status IN ('ACTIVE','TERMINATED','EXPIRED') AND start_date<=p_as_of;
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
    FROM v_invoice_balance b JOIN lease l ON l.lease_id=b.lease_id
    JOIN user_account ua ON ua.person_id=l.tenant_id AND ua.actor_role='TENANT_BUYER'
    WHERE b.invoice_status IN ('DUE','PARTIALLY_PAID') AND b.balance_due>0
      AND b.due_date BETWEEN p_as_of AND DATE_ADD(p_as_of,INTERVAL 7 DAY);

    INSERT IGNORE INTO notification(account_id,notification_type,dedupe_key,title,message,invoice_id)
    SELECT ua.account_id,'INVOICE_OVERDUE',CONCAT('invoice:',b.invoice_id,':overdue'),
           'Rent payment overdue',CONCAT('Invoice #',b.invoice_id,' was due on ',DATE_FORMAT(b.due_date,'%Y-%m-%d'),'. Balance: ',FORMAT(b.balance_due,0),' VND.'),b.invoice_id
    FROM v_invoice_balance b JOIN lease l ON l.lease_id=b.lease_id
    JOIN user_account ua ON ua.person_id=l.tenant_id AND ua.actor_role='TENANT_BUYER'
    WHERE b.invoice_status='OVERDUE' AND b.balance_due>0;

    INSERT IGNORE INTO notification(account_id,notification_type,dedupe_key,title,message,invoice_id)
    SELECT ua.account_id,'INVOICE_OVERDUE',CONCAT('admin:invoice:',b.invoice_id,':overdue'),
           'Overdue rent invoice',CONCAT('Invoice #',b.invoice_id,' for lease #',b.lease_id,' is overdue. Balance: ',FORMAT(b.balance_due,0),' VND.'),b.invoice_id
    FROM v_invoice_balance b JOIN user_account ua ON ua.actor_role='ADMIN'
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
    FROM lease l JOIN user_account ua ON ua.person_id IN (l.tenant_id,l.agent_id) OR ua.actor_role='ADMIN'
    WHERE l.status='ACTIVE' AND l.end_date BETWEEN p_as_of AND DATE_ADD(p_as_of,INTERVAL 30 DAY);
END$$
DELIMITER ;

CREATE OR REPLACE VIEW v_invoice_balance AS
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

CREATE OR REPLACE VIEW v_overdue_invoices AS
SELECT b.*,l.tenant_id,l.agent_id,p.property_id,p.title
FROM v_invoice_balance b JOIN lease l ON l.lease_id=b.lease_id JOIN property p ON p.property_id=l.property_id
WHERE b.invoice_status='OVERDUE';

CALL sp_generate_rental_invoices(CURRENT_DATE);

-- Preserve historical rent receipts in the new invoice ledger. A receipt is
-- matched to the invoice for the calendar month in which it was paid; deposits,
-- fees, and refunds are intentionally left unlinked because their invoice period
-- cannot be inferred reliably from the old schema.
UPDATE payment pay
JOIN rental_invoice i
  ON i.lease_id=pay.lease_id
 AND pay.payment_date BETWEEN i.period_start AND i.period_end
SET pay.invoice_id=i.invoice_id
WHERE pay.invoice_id IS NULL
  AND pay.payment_type='RENT'
  AND pay.payment_date<=CURRENT_DATE;

CALL sp_refresh_notifications(CURRENT_DATE);

-- Review exact duplicate candidates before changing historical records. Existing
-- entries are deliberately retained; some same-day partial payments can be valid.
SELECT lease_id,invoice_id,payment_date,amount,payment_type,payment_method,reference_code,COUNT(*) AS duplicate_count
FROM payment WHERE status='POSTED'
GROUP BY lease_id,invoice_id,payment_date,amount,payment_type,payment_method,reference_code
HAVING COUNT(*)>1;
