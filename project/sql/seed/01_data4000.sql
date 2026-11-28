-- Deterministic synthetic demo data with Vietnamese-style personal names; creates at least 4,000 rows.
-- Run once after schema objects are installed and an active Admin account has been created in the UI.
USE reims_db;
DELIMITER $$
DROP PROCEDURE IF EXISTS seed_reims_demo$$
DROP FUNCTION IF EXISTS seed_vietnamese_person_name$$
CREATE FUNCTION seed_vietnamese_person_name(p_person_id BIGINT UNSIGNED)
RETURNS VARCHAR(100)
DETERMINISTIC
NO SQL
BEGIN
    RETURN CONCAT(
        ELT(1 + MOD(p_person_id * 7 + 3, 19),
            'Nguyen','Tran','Le','Pham','Hoang','Huynh','Phan','Vu','Vo','Dang','Bui','Do','Ho','Ngo','Duong','Ly','Truong','Cao','Ta'),
        ' ',
        IF(MOD(p_person_id, 2) = 0,
            ELT(1 + MOD(p_person_id * 11 + 7, 41),
                'Van An','Van Binh','Van Cuong','Van Dat','Van Duc','Van Dung','Van Hao','Van Hieu','Van Huan','Van Hung','Van Khai','Van Khanh','Van Khoa','Van Lam','Van Long','Van Minh','Van Nam','Van Phong','Van Phuc','Van Quan','Van Quang','Van Son','Van Tai','Van Tam','Van Thang','Van Thien','Van Thinh','Van Tuan','Van Tung','Van Viet','Van Vinh','Huu Huy','Duc Tien','Minh Quan','Quoc Bao','Thanh Cong','Gia Bao','Bao Long','Tuan Kiet','Trong Nghia','Dinh La'),
            ELT(1 + MOD(p_person_id * 11 + 7, 41),
                'Thi An','Thi Anh','Thi Bich','Thi Chau','Thi Chi','Thi Dung','Thi Giang','Thi Ha','Thi Hanh','Thi Hien','Thi Hoa','Thi Huong','Thi Khanh','Thi Lan','Thi Linh','Thi Mai','Thi My','Thi Nga','Thi Ngoc','Thi Nhi','Thi Phuong','Thi Quyen','Thi Thao','Thi Trang','Thi Trinh','Thi Truc','Thi Tuyet','Thi Uyen','Thi Van','Thi Vy','Thi Yen','Ngoc Anh','Ngoc Han','Thanh Tam','Minh Chau','Hoai Thu','Thuy Tien','Kim Ngan','Thu Ha','My Linh','Phuong Thao'))
    );
END$$
CREATE PROCEDURE seed_reims_demo()
BEGIN
    DECLARE i INT DEFAULT 1;
    DECLARE v_status VARCHAR(30);
    DECLARE v_listing VARCHAR(20);
    DECLARE v_type VARCHAR(20);
    DECLARE v_property_id BIGINT;
    DECLARE v_lease_id BIGINT;
    DECLARE v_invoice_id BIGINT UNSIGNED;
    DECLARE v_start DATE;
    DECLARE v_end DATE;
    DECLARE v_rent DECIMAL(15,2);
    DECLARE v_person_id BIGINT;
    DECLARE v_payment_date DATE;
    DECLARE v_sale_property_id BIGINT UNSIGNED;
    DECLARE v_sale_agent_id BIGINT UNSIGNED;
    DECLARE v_sale_price DECIMAL(15,2);
    DECLARE v_commission_rate DECIMAL(5,2);
    DECLARE v_reviewer_account_id BIGINT UNSIGNED;

    SET v_reviewer_account_id = (
        SELECT MIN(account_id) FROM user_account
        WHERE actor_role='ADMIN' AND is_active=TRUE
    );
    IF v_reviewer_account_id IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Create and activate an Admin account in the UI before loading demo data';
    END IF;

    -- 40 agents, 100 owners, 1,060 tenants = 1,200 people.
    SET i=1;
    WHILE i<=40 DO
        SET v_person_id=i;
        INSERT INTO person(person_id,full_name,phone,email) VALUES
          (v_person_id,seed_vietnamese_person_name(v_person_id),CONCAT('+849000',LPAD(i,4,'0')),CONCAT('agent',i,'@reims.demo'));
        INSERT INTO agent(person_id,commission_rate) VALUES(v_person_id, 2.50 + (i MOD 6)*0.25);
        SET i=i+1;
    END WHILE;
    SET i=1;
    WHILE i<=100 DO
        SET v_person_id=40+i;
        INSERT INTO person(person_id,full_name,phone,email) VALUES
          (v_person_id,seed_vietnamese_person_name(v_person_id),CONCAT('+848000',LPAD(i,4,'0')),CONCAT('owner',i,'@reims.demo'));
        INSERT INTO owner(person_id,mailing_address) VALUES(v_person_id,CONCAT(i,' Nguyen Trai, District ',1+(i MOD 12),', Ho Chi Minh City'));
        SET i=i+1;
    END WHILE;
    SET i=1;
    WHILE i<=1060 DO
        SET v_person_id=140+i;
        INSERT INTO person(person_id,full_name,phone,email) VALUES
          (v_person_id,seed_vietnamese_person_name(v_person_id),CONCAT('+847000',LPAD(i,4,'0')),CONCAT('tenant',i,'@reims.demo'));
        INSERT INTO tenant(person_id,id_card_number) VALUES(v_person_id,CONCAT('ID',LPAD(i,10,'0')));
        SET i=i+1;
    END WHILE;

    -- 300 properties; subtype rows are partitioned by property_type.
    SET i=1;
    WHILE i<=300 DO
        SET v_type=IF(i MOD 2=0,'RESIDENTIAL','COMMERCIAL');
        SET v_listing=IF(i<=150,'FOR_RENT',IF(i>=291,'FOR_SALE',IF(i MOD 2=0,'FOR_SALE','FOR_RENT')));
        -- Lease and maintenance triggers set the current state as those records are inserted.
        SET v_status='AVAILABLE';
        INSERT INTO property(property_id,title,address,property_type,listing_type,asking_price,status,owner_id,agent_id)
        VALUES(i,CONCAT(v_type,' property ',LPAD(i,3,'0')),CONCAT(i,' Le Loi, District ',1+(i MOD 12),', Ho Chi Minh City'),
               v_type,v_listing,IF(v_listing='FOR_RENT',8000000+(i MOD 15)*1000000,1800000000+(i MOD 20)*150000000),
               v_status,41+((i-1) MOD 100),1+((i-1) MOD 40));
        IF v_type='RESIDENTIAL' THEN
            INSERT INTO residential_property(property_id,bedrooms,bathrooms,area_sqm,furnished_status)
            VALUES(i,1+(i MOD 5),1+(i MOD 3),35+(i MOD 12)*8,ELT(1+(i MOD 3),'FURNISHED','PARTLY_FURNISHED','UNFURNISHED'));
        ELSE
            INSERT INTO commercial_property(property_id,business_type,floor_area_sqm,parking_spaces)
            VALUES(i,ELT(1+(i MOD 4),'OFFICE','RETAIL','WAREHOUSE','SERVICE'),50+(i MOD 20)*15,i MOD 12);
        END IF;
        SET i=i+1;
    END WHILE;

    -- 150 completed historical leases + 150 current leases for properties 1..150.
    SET i=1;
    WHILE i<=300 DO
        SET v_property_id=1+((i-1) MOD 150);
        SET v_start=IF(i<=150,DATE_ADD('2023-01-01',INTERVAL (i MOD 12) MONTH),DATE_ADD('2025-01-01',INTERVAL (i MOD 12) MONTH));
        SET v_end=IF(i<=150,DATE_ADD(v_start,INTERVAL 1 YEAR),DATE_ADD(v_start,INTERVAL 3 YEAR));
        SET v_rent=8000000+(v_property_id MOD 15)*1000000;
        INSERT INTO lease(lease_id,start_date,end_date,monthly_rent,deposit_amount,payment_day,status,property_id,tenant_id,agent_id)
        VALUES(i,v_start,v_end,v_rent,v_rent,5+(i MOD 20),'PENDING',v_property_id,141+((i-1) MOD 1060),1+((v_property_id-1) MOD 40));
        SET i=i+1;
    END WHILE;

    -- Simulate reviewed historical leases through the same approved lifecycle as the UI.
    UPDATE lease
    SET status='ACTIVE',reviewed_by_account_id=v_reviewer_account_id,reviewed_at=NOW()
    WHERE lease_id BETWEEN 1 AND 150 AND status='PENDING';
    UPDATE lease SET status='TERMINATED' WHERE lease_id BETWEEN 1 AND 150 AND status='ACTIVE';
    UPDATE lease
    SET status='ACTIVE',reviewed_by_account_id=v_reviewer_account_id,reviewed_at=NOW()
    WHERE lease_id BETWEEN 151 AND 300 AND status='PENDING';

    -- Create one invoice for each lease month up to today, including ended leases.
    CALL sp_generate_rental_invoices(CURRENT_DATE);

    -- Two posted receipts per lease. Each rent receipt is matched to its invoice
    -- and has an idempotency key so a retried insert cannot create a duplicate.
    SET i=1;
    WHILE i<=600 DO
        SET v_lease_id=1+FLOOR((i-1)/2);
        SELECT CASE WHEN l.status='ACTIVE' AND i MOD 2=0 THEN CURRENT_DATE
                    WHEN i MOD 2=1 THEN DATE_ADD(l.start_date,INTERVAL 3 DAY)
                    ELSE DATE_ADD(DATE_ADD(l.start_date,INTERVAL 1 MONTH),INTERVAL 3 DAY) END
        INTO v_payment_date FROM lease l WHERE l.lease_id=v_lease_id;
        SELECT ri.invoice_id INTO v_invoice_id
        FROM rental_invoice ri JOIN lease l ON l.lease_id=ri.lease_id
        WHERE ri.lease_id=v_lease_id
          AND ri.period_start=GREATEST(STR_TO_DATE(CONCAT(YEAR(v_payment_date),'-',LPAD(MONTH(v_payment_date),2,'0'),'-01'),'%Y-%m-%d'),l.start_date)
        LIMIT 1;
        SELECT monthly_rent INTO v_rent FROM lease WHERE lease_id=v_lease_id;
        INSERT INTO payment(lease_id,invoice_id,payment_date,amount,payment_type,payment_method,reference_code,idempotency_key,status)
        VALUES(v_lease_id,v_invoice_id,v_payment_date,v_rent,'RENT',
               ELT(1+(i MOD 4),'BANK_TRANSFER','CASH','CARD','E_WALLET'),
               CONCAT('DEMO-PAY-',LPAD(i,6,'0')),UUID(),'POSTED');
        SET i=i+1;
    END WHILE;

    -- Ten completed sale transactions on properties 291..300; commission is
    -- calculated and stored from the agent rate snapshot at closing.
    SET i=1;
    WHILE i<=10 DO
        SELECT property_id,agent_id,asking_price INTO v_sale_property_id,v_sale_agent_id,v_sale_price
        FROM property WHERE property_id=290+i;
        SELECT commission_rate INTO v_commission_rate FROM agent WHERE person_id=v_sale_agent_id;
        INSERT INTO sale_transaction(property_id,buyer_id,agent_id,sale_price,commission_rate_at_sale,
                                     status,contract_date)
        VALUES(v_sale_property_id,141+((i-1) MOD 1060),v_sale_agent_id,
               ROUND(v_sale_price*(0.94+(i MOD 5)*0.01),2),v_commission_rate,
               'PENDING',DATE_SUB(CURRENT_DATE,INTERVAL i DAY));
        SET i=i+1;
    END WHILE;
    UPDATE sale_transaction
    SET status='APPROVED',reviewed_by_account_id=v_reviewer_account_id,reviewed_at=NOW()
    WHERE status='PENDING' AND property_id BETWEEN 291 AND 300;
    UPDATE sale_transaction
    SET status='CLOSED',closing_date=contract_date,reviewed_by_account_id=v_reviewer_account_id,reviewed_at=NOW()
    WHERE status='APPROVED' AND property_id BETWEEN 291 AND 300;

    -- 100 repair requests tied to current leases; first ten remain in progress.
    SET i=1;
    WHILE i<=100 DO
        INSERT INTO maintenance_request(lease_id,description,report_date,estimated_cost,actual_cost,status,resolved_at)
        VALUES(150+i,ELT(1+(i MOD 5),'Water leak inspection','Air conditioner repair','Electrical socket repair','Door lock replacement','Paint and wall repair'),
               DATE_ADD('2026-01-01',INTERVAL i DAY),500000+(i MOD 10)*150000,
               NULL,'PENDING',NULL);
        SET i=i+1;
    END WHILE;
    UPDATE maintenance_request
    SET status='IN_PROGRESS',reviewed_by_account_id=v_reviewer_account_id,reviewed_at=NOW()
    WHERE request_id BETWEEN 1 AND 10 AND status='PENDING';
    UPDATE maintenance_request
    SET status='IN_PROGRESS',reviewed_by_account_id=v_reviewer_account_id,reviewed_at=NOW()
    WHERE request_id BETWEEN 11 AND 100 AND status='PENDING';
    UPDATE maintenance_request
    SET status='COMPLETED',actual_cost=500000+(request_id MOD 10)*130000,
        resolved_at=DATE_ADD('2026-01-02',INTERVAL request_id DAY),
        reviewed_by_account_id=v_reviewer_account_id,reviewed_at=NOW()
    WHERE request_id BETWEEN 11 AND 100 AND status='IN_PROGRESS';

END$$
CALL seed_reims_demo()$$
DROP PROCEDURE seed_reims_demo$$
DROP FUNCTION seed_vietnamese_person_name$$
DELIMITER ;

-- Quick row-count summary; expected total is at least 4,000 rows.
SELECT 'person' AS table_name, COUNT(*) AS row_count FROM person
UNION ALL SELECT 'property',COUNT(*) FROM property
UNION ALL SELECT 'owner',COUNT(*) FROM owner
UNION ALL SELECT 'agent',COUNT(*) FROM agent
UNION ALL SELECT 'tenant',COUNT(*) FROM tenant
UNION ALL SELECT 'residential_property',COUNT(*) FROM residential_property
UNION ALL SELECT 'commercial_property',COUNT(*) FROM commercial_property
UNION ALL SELECT 'lease',COUNT(*) FROM lease
UNION ALL SELECT 'rental_invoice',COUNT(*) FROM rental_invoice
UNION ALL SELECT 'payment',COUNT(*) FROM payment
UNION ALL SELECT 'sale_transaction',COUNT(*) FROM sale_transaction
UNION ALL SELECT 'maintenance_request',COUNT(*) FROM maintenance_request
UNION ALL SELECT 'notification',COUNT(*) FROM notification;
