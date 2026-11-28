USE reims_db;

-- Q18. Recent in-app notifications for the current user's account; replace 1 with account_id.
SELECT notification_id,notification_type,title,message,is_read,created_at
FROM notification
WHERE account_id=1
ORDER BY created_at DESC,notification_id DESC
LIMIT 100;
