USE reims_db;

-- Q7. Properties with open maintenance work and their current lease/tenant.
SELECT p.property_id,p.title,p.status,m.request_id,m.description,m.status AS repair_status,
       l.lease_id,tp.full_name AS tenant_name
FROM property p JOIN lease l ON l.property_id=p.property_id AND l.status='ACTIVE'
JOIN maintenance_request m ON m.lease_id=l.lease_id AND m.status IN ('PENDING','IN_PROGRESS')
JOIN tenant t ON t.person_id=l.tenant_id JOIN person tp ON tp.person_id=t.person_id
ORDER BY m.report_date;
