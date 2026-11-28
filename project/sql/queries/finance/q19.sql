USE reims_db;

-- Q19. Review possible exact duplicate posted payments before manual cleanup.
-- Same amount/date can be legitimate installments, so this is an audit report,
-- not an instruction to delete rows automatically.
SELECT lease_id,invoice_id,payment_date,amount,payment_type,payment_method,reference_code,
       COUNT(*) AS duplicate_count,GROUP_CONCAT(payment_id ORDER BY payment_id) AS payment_ids
FROM payment
WHERE status='POSTED'
GROUP BY lease_id,invoice_id,payment_date,amount,payment_type,payment_method,reference_code
HAVING COUNT(*)>1
ORDER BY duplicate_count DESC,payment_date DESC;
