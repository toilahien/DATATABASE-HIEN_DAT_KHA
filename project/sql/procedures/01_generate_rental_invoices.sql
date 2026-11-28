-- Generate one invoice per eligible lease month through the supplied date.
USE reims_db;
DELIMITER $$
DROP PROCEDURE IF EXISTS sp_generate_rental_invoices$$
CREATE PROCEDURE sp_generate_rental_invoices(IN p_as_of DATE)
BEGIN
    DECLARE v_done BOOLEAN DEFAULT FALSE;
    DECLARE v_lease_id BIGINT UNSIGNED;
    DECLARE v_start DATE;
    DECLARE v_end DATE;
    DECLARE v_rent DECIMAL(15,2);
    DECLARE v_payment_day TINYINT UNSIGNED;
    DECLARE v_month DATE;
    DECLARE v_last_month DATE;
    DECLARE v_period_start DATE;
    DECLARE v_period_end DATE;
    DECLARE v_due_date DATE;
    DECLARE lease_cursor CURSOR FOR
        SELECT lease_id,start_date,end_date,monthly_rent,payment_day
        FROM lease
        WHERE status IN ('ACTIVE','TERMINATED','EXPIRED') AND start_date<=p_as_of;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done=TRUE;

    IF p_as_of IS NULL OR p_as_of > CURRENT_DATE THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invoice generation date cannot be null or in the future';
    END IF;

    OPEN lease_cursor;
    lease_loop: LOOP
        FETCH lease_cursor INTO v_lease_id,v_start,v_end,v_rent,v_payment_day;
        IF v_done THEN LEAVE lease_loop; END IF;
        SET v_month=STR_TO_DATE(CONCAT(YEAR(v_start),'-',LPAD(MONTH(v_start),2,'0'),'-01'),'%Y-%m-%d');
        SET v_last_month=STR_TO_DATE(CONCAT(YEAR(LEAST(v_end,p_as_of)),'-',LPAD(MONTH(LEAST(v_end,p_as_of)),2,'0'),'-01'),'%Y-%m-%d');
        WHILE v_month<=v_last_month DO
            SET v_period_start=GREATEST(v_start,v_month);
            SET v_period_end=LEAST(v_end,LAST_DAY(v_month));
            SET v_due_date=DATE_ADD(v_month,INTERVAL (LEAST(v_payment_day,DAY(LAST_DAY(v_month)))-1) DAY);
            IF v_due_date<v_period_start THEN SET v_due_date=v_period_start; END IF;
            INSERT IGNORE INTO rental_invoice(lease_id,period_start,period_end,issue_date,due_date,amount_due)
            VALUES(v_lease_id,v_period_start,v_period_end,v_period_start,v_due_date,v_rent);
            SET v_month=DATE_ADD(v_month,INTERVAL 1 MONTH);
        END WHILE;
    END LOOP;
    CLOSE lease_cursor;
END$$
DELIMITER ;
