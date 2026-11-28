USE reims_db;

-- Q4. Latest posted cash receipts, with the property, tenant, and lease.
SELECT pay.payment_id,pay.payment_date,pay.payment_type,
       CASE WHEN pay.payment_type='REFUND' THEN -pay.amount ELSE pay.amount END AS net_amount,
       pay.payment_method,
       p.property_id,p.title,pe.full_name AS tenant_name,l.lease_id
FROM payment pay JOIN lease l ON l.lease_id=pay.lease_id
JOIN property p ON p.property_id=l.property_id
JOIN tenant t ON t.person_id=l.tenant_id JOIN person pe ON pe.person_id=t.person_id
WHERE pay.status='POSTED'
ORDER BY pay.payment_date DESC,pay.payment_id DESC LIMIT 100;
