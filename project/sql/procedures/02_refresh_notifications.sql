-- Refresh lease status and due/overdue notifications through the supplied date.
USE reims_db;
DELIMITER $$
DROP PROCEDURE IF EXISTS sp_refresh_notifications$$
CREATE PROCEDURE sp_refresh_notifications(IN p_as_of DATE)
BEGIN
    IF p_as_of IS NULL OR p_as_of > CURRENT_DATE THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Notification refresh date cannot be null or in the future';
    END IF;

    -- Expire leases after their contractual end date; lease triggers restore the
    -- property state while respecting any maintenance work still in progress.
    UPDATE lease SET status='EXPIRED'
    WHERE status='ACTIVE' AND end_date<p_as_of;

    UPDATE notification n
    JOIN v_invoice_balance b ON b.invoice_id=n.invoice_id
    SET n.is_read=TRUE
    WHERE n.notification_type='INVOICE_DUE'
      AND (b.invoice_status NOT IN ('DUE','PARTIALLY_PAID') OR b.due_date<p_as_of);

    UPDATE notification n
    JOIN v_invoice_balance b ON b.invoice_id=n.invoice_id
    SET n.is_read=TRUE
    WHERE n.notification_type='INVOICE_OVERDUE'
      AND b.invoice_status<>'OVERDUE';

    INSERT IGNORE INTO notification(account_id,notification_type,dedupe_key,title,message,invoice_id)
    SELECT ua.account_id,'INVOICE_DUE',CONCAT('invoice:',b.invoice_id,':due'),
           'Rent payment due soon',CONCAT('Invoice #',b.invoice_id,' is due on ',DATE_FORMAT(b.due_date,'%Y-%m-%d'),'. Balance: ',FORMAT(b.balance_due,0),' VND.'),b.invoice_id
    FROM v_invoice_balance b
    JOIN lease l ON l.lease_id=b.lease_id
    JOIN user_account ua ON ua.person_id=l.tenant_id AND ua.actor_role='TENANT_BUYER'
    WHERE ua.is_active=TRUE AND b.invoice_status IN ('DUE','PARTIALLY_PAID') AND b.balance_due>0
      AND b.due_date BETWEEN p_as_of AND DATE_ADD(p_as_of,INTERVAL 7 DAY);

    INSERT IGNORE INTO notification(account_id,notification_type,dedupe_key,title,message,invoice_id)
    SELECT ua.account_id,'INVOICE_OVERDUE',CONCAT('invoice:',b.invoice_id,':overdue'),
           'Rent payment overdue',CONCAT('Invoice #',b.invoice_id,' was due on ',DATE_FORMAT(b.due_date,'%Y-%m-%d'),'. Balance: ',FORMAT(b.balance_due,0),' VND.'),b.invoice_id
    FROM v_invoice_balance b
    JOIN lease l ON l.lease_id=b.lease_id
    JOIN user_account ua ON ua.person_id=l.tenant_id AND ua.actor_role='TENANT_BUYER'
    WHERE ua.is_active=TRUE AND b.invoice_status='OVERDUE' AND b.balance_due>0;

    INSERT IGNORE INTO notification(account_id,notification_type,dedupe_key,title,message,invoice_id)
    SELECT ua.account_id,'INVOICE_OVERDUE',CONCAT('admin:invoice:',b.invoice_id,':overdue'),
           'Overdue rent invoice',CONCAT('Invoice #',b.invoice_id,' for lease #',b.lease_id,' is overdue. Balance: ',FORMAT(b.balance_due,0),' VND.'),b.invoice_id
    FROM v_invoice_balance b
    JOIN user_account ua ON ua.actor_role='ADMIN'
    WHERE ua.is_active=TRUE AND b.invoice_status='OVERDUE' AND b.balance_due>0;

    INSERT IGNORE INTO notification(account_id,notification_type,dedupe_key,title,message)
    SELECT ua.account_id,'LEASE_EXPIRED',CONCAT('lease:',l.lease_id,':expired'),
           'Lease has expired',CONCAT('Lease #',l.lease_id,' ended on ',DATE_FORMAT(l.end_date,'%Y-%m-%d'),'.')
    FROM lease l
    JOIN user_account ua ON (ua.person_id IN (l.tenant_id,l.agent_id) OR ua.actor_role='ADMIN')
    WHERE ua.is_active=TRUE AND l.status='EXPIRED' AND l.end_date<p_as_of;

    INSERT IGNORE INTO notification(account_id,notification_type,dedupe_key,title,message)
    SELECT ua.account_id,'LEASE_EXPIRING',CONCAT('lease:',l.lease_id,':expiring'),
           'Lease ending soon',CONCAT('Lease #',l.lease_id,' ends on ',DATE_FORMAT(l.end_date,'%Y-%m-%d'),'.')
    FROM lease l
    JOIN user_account ua ON (ua.person_id IN (l.tenant_id,l.agent_id) OR ua.actor_role='ADMIN')
    WHERE ua.is_active=TRUE AND l.status='ACTIVE' AND l.end_date BETWEEN p_as_of AND DATE_ADD(p_as_of,INTERVAL 30 DAY);
END$$
DELIMITER ;
