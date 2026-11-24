USE reims_db;

-- Q1. Search available rental listings by budget and property type.
SELECT d.property_id,d.title,d.address,d.property_type,d.asking_price
FROM v_property_dashboard d
WHERE d.status='AVAILABLE' AND d.listing_type='FOR_RENT'
  AND d.asking_price BETWEEN 8000000 AND 20000000
ORDER BY d.asking_price;

-- Q2. Inventory and occupancy by property type. Occupancy comes from active leases,
-- so a property under maintenance is still counted as leased when its lease is active.
SELECT p.property_type,COUNT(*) AS total_properties,
       SUM(CASE WHEN al.property_id IS NOT NULL THEN 1 ELSE 0 END) AS leased,
       SUM(p.status='AVAILABLE') AS available,
       SUM(p.status='UNDER_MAINTENANCE') AS under_maintenance,
       ROUND(100*SUM(CASE WHEN al.property_id IS NOT NULL THEN 1 ELSE 0 END)/NULLIF(COUNT(*),0),2) AS leased_percent
FROM property p
LEFT JOIN (SELECT DISTINCT property_id FROM lease WHERE status='ACTIVE') al ON al.property_id=p.property_id
GROUP BY p.property_type;

-- Q3. Owner portfolio and total posted rent receipts, including historical leases.
SELECT o.person_id,op.full_name,COUNT(DISTINCT p.property_id) AS property_count,
       COALESCE(SUM(CASE WHEN pay.payment_type='RENT' AND pay.status='POSTED' THEN pay.amount ELSE 0 END),0) AS rent_received
FROM owner o JOIN person op ON op.person_id=o.person_id
LEFT JOIN property p ON p.owner_id=o.person_id
LEFT JOIN lease l ON l.property_id=p.property_id
LEFT JOIN payment pay ON pay.lease_id=l.lease_id
GROUP BY o.person_id,op.full_name
ORDER BY rent_received DESC;

-- Q4. Latest posted cash receipts, with the property, tenant, and lease.
SELECT pay.payment_id,pay.payment_date,pay.payment_type,pay.amount,pay.payment_method,
       p.property_id,p.title,pe.full_name AS tenant_name,l.lease_id
FROM payment pay JOIN lease l ON l.lease_id=pay.lease_id
JOIN property p ON p.property_id=l.property_id
JOIN tenant t ON t.person_id=l.tenant_id JOIN person pe ON pe.person_id=t.person_id
WHERE pay.status='POSTED'
ORDER BY pay.payment_date DESC,pay.payment_id DESC LIMIT 100;

-- Q5. Agent activity and posted rent receipts, using separate aggregates to avoid multiplication.
SELECT a.person_id,pe.full_name,a.commission_rate,
       COALESCE(lc.lease_count,0) AS lease_count,
       COALESCE(rc.rent_received,0) AS rent_received
FROM agent a JOIN person pe ON pe.person_id=a.person_id
LEFT JOIN (SELECT agent_id,COUNT(*) AS lease_count FROM lease GROUP BY agent_id) lc ON lc.agent_id=a.person_id
LEFT JOIN (
    SELECT l.agent_id,SUM(pay.amount) AS rent_received
    FROM lease l JOIN payment pay ON pay.lease_id=l.lease_id
    WHERE pay.status='POSTED' AND pay.payment_type='RENT'
    GROUP BY l.agent_id
) rc ON rc.agent_id=a.person_id
ORDER BY rent_received DESC,lease_count DESC;

-- Q6. Tenants who have never signed a lease.
SELECT t.person_id,p.full_name
FROM tenant t JOIN person p ON p.person_id=t.person_id
WHERE NOT EXISTS (SELECT 1 FROM lease l WHERE l.tenant_id=t.person_id)
ORDER BY p.full_name;

-- Q7. Properties with open maintenance work and their current lease/tenant.
SELECT p.property_id,p.title,p.status,m.request_id,m.description,m.status AS repair_status,
       l.lease_id,tp.full_name AS tenant_name
FROM property p JOIN lease l ON l.property_id=p.property_id AND l.status='ACTIVE'
JOIN maintenance_request m ON m.lease_id=l.lease_id AND m.status IN ('PENDING','IN_PROGRESS')
JOIN tenant t ON t.person_id=l.tenant_id JOIN person tp ON tp.person_id=t.person_id
ORDER BY m.report_date;

-- Q8. Active leases without a posted rent receipt.
SELECT l.lease_id,l.property_id,l.tenant_id,l.monthly_rent
FROM lease l
WHERE l.status='ACTIVE'
  AND NOT EXISTS (
      SELECT 1 FROM payment pay
      WHERE pay.lease_id=l.lease_id AND pay.payment_type='RENT' AND pay.status='POSTED'
  )
ORDER BY l.lease_id;

-- Q9. Monthly net cash flow for the last 12 months.
SELECT DATE_FORMAT(payment_date,'%Y-%m') AS month,
       SUM(CASE WHEN payment_type='REFUND' THEN -amount ELSE amount END) AS net_cash_received,
       COUNT(*) AS payment_count
FROM payment
WHERE status='POSTED' AND payment_date >= DATE_SUB(CURRENT_DATE,INTERVAL 12 MONTH)
GROUP BY DATE_FORMAT(payment_date,'%Y-%m')
ORDER BY month;

-- Q10. Properties whose area is above the average for their own subtype.
WITH all_areas AS (
    SELECT p.property_id,p.title,p.property_type,r.area_sqm AS area
    FROM property p JOIN residential_property r ON r.property_id=p.property_id
    UNION ALL
    SELECT p.property_id,p.title,p.property_type,c.floor_area_sqm AS area
    FROM property p JOIN commercial_property c ON c.property_id=p.property_id
), subtype_avg AS (
    SELECT property_type,AVG(area) AS avg_area FROM all_areas GROUP BY property_type
)
SELECT x.property_id,x.title,x.property_type,x.area,a.avg_area
FROM all_areas x JOIN subtype_avg a USING(property_type)
WHERE x.area>a.avg_area ORDER BY x.property_type,x.area DESC;

-- Q11. Active leases ending within 60 days, including tenant and agent contacts.
SELECT l.lease_id,l.end_date,l.monthly_rent,
       tp.full_name AS tenant_name,tp.phone AS tenant_phone,
       ap.full_name AS agent_name,ap.phone AS agent_phone
FROM lease l JOIN tenant t ON t.person_id=l.tenant_id JOIN person tp ON tp.person_id=t.person_id
JOIN agent a ON a.person_id=l.agent_id JOIN person ap ON ap.person_id=a.person_id
WHERE l.status='ACTIVE' AND l.end_date BETWEEN CURRENT_DATE AND DATE_ADD(CURRENT_DATE,INTERVAL 60 DAY)
ORDER BY l.end_date;

-- Q12. Properties whose cumulative posted rent receipts exceed average property receipts.
WITH property_revenue AS (
    SELECT p.property_id,p.title,
           COALESCE(SUM(CASE WHEN pay.payment_type='RENT' AND pay.status='POSTED' THEN pay.amount ELSE 0 END),0) AS rent_received
    FROM property p LEFT JOIN lease l ON l.property_id=p.property_id
    LEFT JOIN payment pay ON pay.lease_id=l.lease_id
    GROUP BY p.property_id,p.title
)
SELECT property_id,title,rent_received
FROM property_revenue
WHERE rent_received > (SELECT AVG(rent_received) FROM property_revenue)
ORDER BY rent_received DESC;

-- Q13. Rent receipts by agent and calendar quarter.
SELECT l.agent_id,pe.full_name,YEAR(pay.payment_date) AS revenue_year,
       QUARTER(pay.payment_date) AS revenue_quarter,SUM(pay.amount) AS rent_received
FROM payment pay JOIN lease l ON l.lease_id=pay.lease_id
JOIN agent a ON a.person_id=l.agent_id JOIN person pe ON pe.person_id=a.person_id
WHERE pay.status='POSTED' AND pay.payment_type='RENT'
GROUP BY l.agent_id,pe.full_name,YEAR(pay.payment_date),QUARTER(pay.payment_date)
ORDER BY revenue_year DESC,revenue_quarter DESC,rent_received DESC;

-- Q14. Available sale listings and total asking value by assigned agent.
SELECT a.person_id,pe.full_name,COUNT(p.property_id) AS sale_listing_count,
       COALESCE(SUM(p.asking_price),0) AS total_asking_value
FROM agent a JOIN person pe ON pe.person_id=a.person_id
LEFT JOIN property p ON p.agent_id=a.person_id AND p.listing_type='FOR_SALE' AND p.status='AVAILABLE'
GROUP BY a.person_id,pe.full_name
ORDER BY total_asking_value DESC;
