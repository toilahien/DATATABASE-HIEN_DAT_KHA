-- Property listing summary with owner, assigned agent, and active lease count.
USE reims_db;
DROP VIEW IF EXISTS v_property_dashboard;

CREATE VIEW v_property_dashboard AS
SELECT p.property_id, p.title, p.address, p.property_type, p.listing_type,
       p.asking_price, p.status, op.full_name AS owner_name, ap.full_name AS agent_name,
       (SELECT COUNT(*) FROM lease l WHERE l.property_id = p.property_id AND l.status = 'ACTIVE') AS active_lease_count
FROM property p
JOIN owner o ON o.person_id = p.owner_id JOIN person op ON op.person_id = o.person_id
JOIN agent a ON a.person_id = p.agent_id JOIN person ap ON ap.person_id = a.person_id;
