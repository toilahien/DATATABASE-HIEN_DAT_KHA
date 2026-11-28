USE reims_db;

-- Q12. Properties whose cumulative posted rent receipts exceed average property receipts.
WITH property_revenue AS (
    SELECT p.property_id,p.title,
           COALESCE(SUM(CASE WHEN pay.status='POSTED' AND pay.payment_type='RENT' THEN pay.amount
                             WHEN pay.status='POSTED' AND pay.payment_type='REFUND' THEN -pay.amount ELSE 0 END),0) AS rent_received
    FROM property p LEFT JOIN lease l ON l.property_id=p.property_id
    LEFT JOIN payment pay ON pay.lease_id=l.lease_id
    GROUP BY p.property_id,p.title
)
SELECT property_id,title,rent_received
FROM property_revenue
WHERE rent_received > (SELECT AVG(rent_received) FROM property_revenue)
ORDER BY rent_received DESC;
