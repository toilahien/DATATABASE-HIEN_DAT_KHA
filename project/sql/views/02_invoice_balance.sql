-- Invoice balances and computed payment status.
USE reims_db;
DROP VIEW IF EXISTS v_invoice_balance;

CREATE VIEW v_invoice_balance AS
SELECT i.invoice_id,i.lease_id,i.period_start,i.period_end,i.issue_date,i.due_date,i.amount_due,i.status,
       i.amount_paid,
       i.amount_due-i.amount_paid AS balance_due,
       CASE WHEN i.status='VOID' THEN 'VOID'
            WHEN i.amount_due<=i.amount_paid THEN 'PAID'
            WHEN i.due_date<CURRENT_DATE THEN 'OVERDUE'
            WHEN i.amount_paid>0 THEN 'PARTIALLY_PAID'
            ELSE 'DUE' END AS invoice_status
FROM rental_invoice i;
