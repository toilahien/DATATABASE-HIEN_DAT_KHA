USE reims_db;

-- Q15. Closed sale transactions and commission amounts frozen at the sale's agent rate.
SELECT s.sale_id,s.property_id,p.title,b.full_name AS buyer_name,ap.full_name AS agent_name,
       s.sale_price,s.commission_rate_at_sale,s.commission_amount,s.closing_date
FROM sale_transaction s
JOIN property p ON p.property_id=s.property_id
JOIN person b ON b.person_id=s.buyer_id
JOIN agent a ON a.person_id=s.agent_id JOIN person ap ON ap.person_id=a.person_id
WHERE s.status='CLOSED'
ORDER BY s.closing_date DESC,s.sale_id DESC;
