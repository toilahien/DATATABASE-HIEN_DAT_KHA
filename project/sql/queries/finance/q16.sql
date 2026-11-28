USE reims_db;

-- Q16. Rental invoices with outstanding balances, including overdue status.
SELECT b.invoice_id,b.lease_id,b.period_start,b.period_end,b.due_date,
       b.amount_due,b.amount_paid,b.balance_due,b.invoice_status,
       p.property_id,p.title,tp.full_name AS tenant_name
FROM v_invoice_balance b
JOIN lease l ON l.lease_id=b.lease_id
JOIN property p ON p.property_id=l.property_id
JOIN tenant t ON t.person_id=l.tenant_id JOIN person tp ON tp.person_id=t.person_id
WHERE b.invoice_status IN ('DUE','PARTIALLY_PAID','OVERDUE')
ORDER BY b.due_date,b.invoice_id;
