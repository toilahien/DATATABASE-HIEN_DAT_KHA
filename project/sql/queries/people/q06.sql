USE reims_db;

-- Q6. Tenants who have never signed a lease.
SELECT t.person_id,p.full_name
FROM tenant t JOIN person p ON p.person_id=t.person_id
WHERE NOT EXISTS (SELECT 1 FROM lease l WHERE l.tenant_id=t.person_id)
ORDER BY p.full_name;
