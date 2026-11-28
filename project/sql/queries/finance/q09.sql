USE reims_db;

-- Q9. Monthly net cash flow for the last 12 months.
SELECT DATE_FORMAT(payment_date,'%Y-%m') AS month,
       SUM(CASE WHEN payment_type='REFUND' THEN -amount ELSE amount END) AS net_cash_received,
       COUNT(*) AS payment_count
FROM payment
WHERE status='POSTED'
  AND payment_date >= DATE_SUB(DATE_SUB(CURRENT_DATE,INTERVAL DAYOFMONTH(CURRENT_DATE)-1 DAY),INTERVAL 11 MONTH)
  AND payment_date <= CURRENT_DATE
GROUP BY DATE_FORMAT(payment_date,'%Y-%m')
ORDER BY month;
