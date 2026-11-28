USE reims_db;

-- Q8. Active leases with a current or overdue invoice balance.
SELECT l.lease_id,l.property_id,l.tenant_id,l.monthly_rent,
       COUNT(b.invoice_id) AS unpaid_invoice_count,SUM(b.balance_due) AS balance_due
FROM lease l JOIN v_invoice_balance b ON b.lease_id=l.lease_id
WHERE l.status='ACTIVE' AND b.invoice_status IN ('DUE','PARTIALLY_PAID','OVERDUE')
GROUP BY l.lease_id,l.property_id,l.tenant_id,l.monthly_rent
ORDER BY balance_due DESC,l.lease_id;
