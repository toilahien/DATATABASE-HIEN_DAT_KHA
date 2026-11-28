USE reims_db;

-- Q17. Agent commission totals from completed sales only.
SELECT a.person_id,pe.full_name,a.commission_rate,
       COUNT(s.sale_id) AS closed_sales,
       COALESCE(SUM(s.sale_price),0) AS closed_sales_value,
       COALESCE(SUM(s.commission_amount),0) AS earned_commission
FROM agent a JOIN person pe ON pe.person_id=a.person_id
LEFT JOIN sale_transaction s ON s.agent_id=a.person_id AND s.status='CLOSED'
GROUP BY a.person_id,pe.full_name,a.commission_rate
ORDER BY earned_commission DESC,closed_sales_value DESC;
