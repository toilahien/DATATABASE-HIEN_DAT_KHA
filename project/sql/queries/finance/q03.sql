USE reims_db;

-- Q3. Owner portfolio and net posted rent receipts, including historical leases.
SELECT o.person_id,op.full_name,COUNT(DISTINCT p.property_id) AS property_count,
       COALESCE(SUM(CASE WHEN pay.status='POSTED' AND pay.payment_type='RENT' THEN pay.amount
                         WHEN pay.status='POSTED' AND pay.payment_type='REFUND' THEN -pay.amount ELSE 0 END),0) AS rent_received
FROM owner o JOIN person op ON op.person_id=o.person_id
LEFT JOIN property p ON p.owner_id=o.person_id
LEFT JOIN lease l ON l.property_id=p.property_id
LEFT JOIN payment pay ON pay.lease_id=l.lease_id
GROUP BY o.person_id,op.full_name
ORDER BY rent_received DESC;
