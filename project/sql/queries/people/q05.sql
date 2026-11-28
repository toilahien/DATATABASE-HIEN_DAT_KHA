USE reims_db;

-- Q5. Agent activity and posted rent receipts, using separate aggregates to avoid multiplication.
SELECT a.person_id,pe.full_name,a.commission_rate,
       COALESCE(lc.lease_count,0) AS lease_count,
       COALESCE(rc.net_rent_received,0) AS net_rent_received
FROM agent a JOIN person pe ON pe.person_id=a.person_id
LEFT JOIN (SELECT agent_id,COUNT(*) AS lease_count FROM lease GROUP BY agent_id) lc ON lc.agent_id=a.person_id
LEFT JOIN (
    SELECT l.agent_id,SUM(CASE WHEN pay.payment_type='RENT' THEN pay.amount ELSE -pay.amount END) AS net_rent_received
    FROM lease l JOIN payment pay ON pay.lease_id=l.lease_id
    WHERE pay.status='POSTED' AND pay.payment_type IN ('RENT','REFUND')
    GROUP BY l.agent_id
) rc ON rc.agent_id=a.person_id
ORDER BY net_rent_received DESC,lease_count DESC;
