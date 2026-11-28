USE reims_db;

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
