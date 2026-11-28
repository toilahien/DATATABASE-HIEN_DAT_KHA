USE reims_db;

-- Q14. Available sale listings and total asking value by assigned agent.
SELECT a.person_id,pe.full_name,COUNT(p.property_id) AS sale_listing_count,
       COALESCE(SUM(p.asking_price),0) AS total_asking_value
FROM agent a JOIN person pe ON pe.person_id=a.person_id
LEFT JOIN property p ON p.agent_id=a.person_id AND p.listing_type='FOR_SALE' AND p.status='AVAILABLE'
GROUP BY a.person_id,pe.full_name
ORDER BY total_asking_value DESC;
