USE reims_db;

-- Q11. Active leases ending within 60 days, including tenant and agent contacts.
SELECT l.lease_id,l.end_date,l.monthly_rent,
       tp.full_name AS tenant_name,tp.phone AS tenant_phone,
       ap.full_name AS agent_name,ap.phone AS agent_phone
FROM lease l JOIN tenant t ON t.person_id=l.tenant_id JOIN person tp ON tp.person_id=t.person_id
JOIN agent a ON a.person_id=l.agent_id JOIN person ap ON ap.person_id=a.person_id
WHERE l.status='ACTIVE' AND l.end_date BETWEEN CURRENT_DATE AND DATE_ADD(CURRENT_DATE,INTERVAL 60 DAY)
ORDER BY l.end_date;
