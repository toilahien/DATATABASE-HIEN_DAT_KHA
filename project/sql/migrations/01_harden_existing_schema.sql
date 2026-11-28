-- One-time, NON-DESTRUCTIVE migration from the earlier 14-table REIMS schema.
-- Back up reims_db before running. Do not run against a fresh install or run twice.
USE reims_db;

ALTER TABLE lease
    ADD COLUMN deposit_paid DECIMAL(15,2) NOT NULL DEFAULT 0 AFTER deposit_amount;

UPDATE lease l
SET l.deposit_paid = COALESCE((
    SELECT SUM(CASE
        WHEN p.status='POSTED' AND p.payment_type='DEPOSIT' AND p.invoice_id IS NULL THEN p.amount
        WHEN p.status='POSTED' AND p.payment_type='REFUND' AND p.invoice_id IS NULL THEN -p.amount
        ELSE 0
    END)
    FROM payment p WHERE p.lease_id=l.lease_id
), 0);

ALTER TABLE lease
    ADD CONSTRAINT chk_lease_deposit_paid CHECK (deposit_paid >= 0 AND deposit_paid <= deposit_amount);

ALTER TABLE rental_invoice
    ADD COLUMN amount_paid DECIMAL(15,2) NOT NULL DEFAULT 0 AFTER amount_due;

-- Carry forward the posted receipts/refunds already in the ledger.
UPDATE rental_invoice i
SET i.amount_paid = COALESCE((
    SELECT SUM(CASE
        WHEN p.status='POSTED' AND p.payment_type='RENT' THEN p.amount
        WHEN p.status='POSTED' AND p.payment_type='REFUND' THEN -p.amount
        ELSE 0
    END)
    FROM payment p WHERE p.invoice_id=i.invoice_id
), 0);

-- Stop if historical balances violate the rule. Correct these ledger rows before
-- continuing and then add the constraint.
ALTER TABLE rental_invoice
    ADD CONSTRAINT chk_invoice_paid CHECK (amount_paid >= 0 AND amount_paid <= amount_due);

ALTER TABLE maintenance_request
    ADD COLUMN reviewed_by_account_id BIGINT UNSIGNED NULL AFTER resolved_at,
    ADD COLUMN reviewed_at DATETIME NULL AFTER reviewed_by_account_id,
    ADD CONSTRAINT fk_maintenance_reviewer FOREIGN KEY (reviewed_by_account_id)
        REFERENCES user_account(account_id) ON DELETE RESTRICT ON UPDATE RESTRICT;

ALTER TABLE sale_transaction
    DROP FOREIGN KEY fk_sale_buyer;

ALTER TABLE sale_transaction
    ADD CONSTRAINT fk_sale_buyer FOREIGN KEY (buyer_id)
        REFERENCES tenant(person_id) ON DELETE RESTRICT ON UPDATE RESTRICT;

-- After this file succeeds, recreate objects in numeric order:
--   sql/triggers/01_account_roles.sql through sql/triggers/08_property_subtypes.sql
--   sql/views/01_property_dashboard.sql through sql/views/03_overdue_invoices.sql
--   sql/procedures/01_generate_rental_invoices.sql through sql/procedures/03_property_admin_updates.sql
