USE reims_db;

-- Q13. Rent receipts by agent and calendar quarter.
SELECT l.agent_id,pe.full_name,YEAR(pay.payment_date) AS revenue_year,
       QUARTER(pay.payment_date) AS revenue_quarter,
       SUM(CASE WHEN pay.payment_type='RENT' THEN pay.amount ELSE -pay.amount END) AS net_rent_received
FROM payment pay JOIN lease l ON l.lease_id=pay.lease_id
JOIN agent a ON a.person_id=l.agent_id JOIN person pe ON pe.person_id=a.person_id
WHERE pay.status='POSTED' AND pay.payment_type IN ('RENT','REFUND')
GROUP BY l.agent_id,pe.full_name,YEAR(pay.payment_date),QUARTER(pay.payment_date)
ORDER BY revenue_year DESC,revenue_quarter DESC,net_rent_received DESC;
