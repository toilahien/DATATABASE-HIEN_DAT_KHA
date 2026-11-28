-- Invoice and payment integrity. Invoice balances are maintained atomically so
-- two concurrent receipts cannot overpay the same invoice.
USE reims_db;
DELIMITER $$

DROP TRIGGER IF EXISTS trg_invoice_guard_insert$$
CREATE TRIGGER trg_invoice_guard_insert
BEFORE INSERT ON rental_invoice
FOR EACH ROW
BEGIN
    DECLARE v_start DATE;
    DECLARE v_end DATE;
    DECLARE v_rent DECIMAL(15,2);
    DECLARE v_status VARCHAR(20);
    DECLARE v_month DATE;

    SELECT start_date, end_date, monthly_rent, status
    INTO v_start, v_end, v_rent, v_status
    FROM lease WHERE lease_id = NEW.lease_id;

    SET v_month = STR_TO_DATE(CONCAT(YEAR(NEW.period_start), '-', LPAD(MONTH(NEW.period_start), 2, '0'), '-01'), '%Y-%m-%d');
    IF NEW.status <> 'ISSUED' OR NEW.amount_paid <> 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'New invoices must be ISSUED with zero paid';
    ELSEIF v_status NOT IN ('ACTIVE', 'TERMINATED', 'EXPIRED') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invoices require an approved lease';
    ELSEIF NEW.period_start <> GREATEST(v_start, v_month)
       OR NEW.period_end <> LEAST(v_end, LAST_DAY(v_month))
       OR NEW.amount_due <> v_rent THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invoice period and amount must match one lease month';
    ELSEIF NEW.issue_date > CURRENT_DATE THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'An invoice cannot be issued in the future';
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_invoice_guard_update$$
CREATE TRIGGER trg_invoice_guard_update
BEFORE UPDATE ON rental_invoice
FOR EACH ROW
BEGIN
    IF NEW.lease_id <> OLD.lease_id OR NEW.period_start <> OLD.period_start
       OR NEW.period_end <> OLD.period_end OR NEW.issue_date <> OLD.issue_date
       OR NEW.due_date <> OLD.due_date OR NEW.amount_due <> OLD.amount_due THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Issued invoice terms are immutable';
    END IF;

    IF NEW.amount_paid <> OLD.amount_paid
       AND COALESCE(@reims_payment_balance_sync, 0) <> 1 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invoice paid balance is maintained by payment records';
    END IF;

    IF NEW.status <> OLD.status THEN
        IF OLD.status <> 'ISSUED' OR NEW.status <> 'VOID' OR OLD.amount_paid <> 0
           OR EXISTS (SELECT 1 FROM payment WHERE invoice_id = OLD.invoice_id) THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Only an unpaid invoice with no payment history can be voided';
        END IF;
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_invoice_no_delete$$
CREATE TRIGGER trg_invoice_no_delete
BEFORE DELETE ON rental_invoice
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invoice history cannot be deleted';
END$$

DROP TRIGGER IF EXISTS trg_payment_guard_insert$$
CREATE TRIGGER trg_payment_guard_insert
BEFORE INSERT ON payment
FOR EACH ROW
BEGIN
    DECLARE v_invoice_lease BIGINT UNSIGNED;
    DECLARE v_amount_due DECIMAL(15,2);
    DECLARE v_amount_paid DECIMAL(15,2);
    DECLARE v_invoice_status VARCHAR(20);
    DECLARE v_lease_start DATE;
    DECLARE v_lease_status VARCHAR(20);
    DECLARE v_deposit_amount DECIMAL(15,2);
    DECLARE v_deposit_paid DECIMAL(15,2);

    SELECT start_date, status, deposit_amount, deposit_paid
    INTO v_lease_start, v_lease_status, v_deposit_amount, v_deposit_paid
    FROM lease WHERE lease_id = NEW.lease_id FOR UPDATE;

    IF NEW.status <> 'POSTED' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'New payment records must be POSTED';
    ELSEIF NEW.payment_date > CURRENT_DATE THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'A payment cannot be recorded with a future date';
    ELSEIF NEW.payment_date < v_lease_start OR v_lease_status NOT IN ('ACTIVE', 'TERMINATED', 'EXPIRED') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Payments require an approved lease and cannot predate its start';
    END IF;

    IF EXISTS (
        SELECT 1 FROM payment p
        WHERE p.lease_id = NEW.lease_id
          AND p.invoice_id <=> NEW.invoice_id
          AND p.payment_date = NEW.payment_date
          AND p.amount = NEW.amount
          AND p.payment_type = NEW.payment_type
          AND p.payment_method <=> NEW.payment_method
          AND p.reference_code <=> NEW.reference_code
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'An identical payment already exists; check its transaction reference';
    END IF;

    IF NEW.payment_type = 'RENT' AND NEW.invoice_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Rent payments must be linked to a rental invoice';
    END IF;

    IF NEW.payment_type = 'DEPOSIT' THEN
        IF NEW.invoice_id IS NOT NULL THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Deposit receipts cannot reference a rent invoice';
        ELSEIF NEW.amount > v_deposit_amount - v_deposit_paid THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Deposit receipt exceeds the lease deposit balance';
        END IF;
    ELSEIF NEW.payment_type = 'REFUND' AND NEW.invoice_id IS NULL
       AND NEW.amount > v_deposit_paid THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Deposit refund exceeds the deposit currently held';
    ELSEIF NEW.payment_type = 'FEE' AND NEW.invoice_id IS NOT NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Fees cannot reference a rent invoice';
    END IF;

    IF NEW.invoice_id IS NOT NULL THEN
        SELECT lease_id, amount_due, amount_paid, status
        INTO v_invoice_lease, v_amount_due, v_amount_paid, v_invoice_status
        FROM rental_invoice WHERE invoice_id = NEW.invoice_id FOR UPDATE;

        IF v_invoice_status <> 'ISSUED' OR v_invoice_lease <> NEW.lease_id THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Payment invoice must be issued and belong to the selected lease';
        ELSEIF NEW.payment_type = 'RENT' AND NEW.amount > v_amount_due - v_amount_paid THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Payment exceeds the remaining invoice balance';
        ELSEIF NEW.payment_type = 'REFUND' AND NEW.amount > v_amount_paid THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Refund exceeds the amount paid on this invoice';
        ELSEIF NEW.payment_type NOT IN ('RENT', 'REFUND') THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Only rent payments or refunds can reference an invoice';
        END IF;
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_payment_balance_insert$$
CREATE TRIGGER trg_payment_balance_insert
AFTER INSERT ON payment
FOR EACH ROW
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SET @reims_payment_balance_sync = NULL;
        RESIGNAL;
    END;
    IF NEW.invoice_id IS NOT NULL THEN
        SET @reims_payment_balance_sync = 1;
        UPDATE rental_invoice
        SET amount_paid = amount_paid + CASE WHEN NEW.payment_type = 'RENT' THEN NEW.amount ELSE -NEW.amount END
        WHERE invoice_id = NEW.invoice_id;
        SET @reims_payment_balance_sync = NULL;
    ELSEIF NEW.payment_type IN ('DEPOSIT', 'REFUND') THEN
        SET @reims_payment_balance_sync = 1;
        UPDATE lease
        SET deposit_paid = deposit_paid + CASE WHEN NEW.payment_type = 'DEPOSIT' THEN NEW.amount ELSE -NEW.amount END
        WHERE lease_id = NEW.lease_id;
        SET @reims_payment_balance_sync = NULL;
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_payment_guard_update$$
CREATE TRIGGER trg_payment_guard_update
BEFORE UPDATE ON payment
FOR EACH ROW
BEGIN
    IF NEW.payment_id <> OLD.payment_id OR NEW.lease_id <> OLD.lease_id
       OR NOT (NEW.invoice_id <=> OLD.invoice_id) OR NEW.payment_date <> OLD.payment_date
       OR NEW.amount <> OLD.amount OR NEW.payment_type <> OLD.payment_type
       OR NOT (NEW.payment_method <=> OLD.payment_method)
       OR NOT (NEW.reference_code <=> OLD.reference_code)
       OR NEW.idempotency_key <> OLD.idempotency_key
       OR NOT (NEW.notes <=> OLD.notes) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Payment details are immutable; reverse and record a correction instead';
    ELSEIF OLD.status <> 'POSTED' OR NEW.status <> 'REVERSED' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'A posted payment can only be reversed once';
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_payment_balance_update$$
CREATE TRIGGER trg_payment_balance_update
AFTER UPDATE ON payment
FOR EACH ROW
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SET @reims_payment_balance_sync = NULL;
        RESIGNAL;
    END;
    IF OLD.invoice_id IS NOT NULL THEN
        SET @reims_payment_balance_sync = 1;
        UPDATE rental_invoice
        SET amount_paid = amount_paid - CASE WHEN OLD.payment_type = 'RENT' THEN OLD.amount ELSE -OLD.amount END
        WHERE invoice_id = OLD.invoice_id;
        SET @reims_payment_balance_sync = NULL;
    ELSEIF OLD.payment_type IN ('DEPOSIT', 'REFUND') THEN
        SET @reims_payment_balance_sync = 1;
        UPDATE lease
        SET deposit_paid = deposit_paid - CASE WHEN OLD.payment_type = 'DEPOSIT' THEN OLD.amount ELSE -OLD.amount END
        WHERE lease_id = OLD.lease_id;
        SET @reims_payment_balance_sync = NULL;
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_payment_no_delete$$
CREATE TRIGGER trg_payment_no_delete
BEFORE DELETE ON payment
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Payment history cannot be deleted; reverse the payment instead';
END$$
DELIMITER ;
