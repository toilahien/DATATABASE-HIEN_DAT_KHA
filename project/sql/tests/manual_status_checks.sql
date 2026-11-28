-- REIMS Phase 4 checks.
-- MySQL setup, row counts, and the UI payment check are already done.
-- Run sql/run_all.sql (MySQL CLI) or the ordered setup in sql/README_VI.md before these checks.
-- The first test block rolls back its temporary records.
-- Run the two checks that should fail one statement at a time. After each error,
-- run ROLLBACK in the same Workbench tab before continuing.
-- Do not execute the whole file as one batch.

USE reims_db;

-- ============================================================
-- Lease and maintenance status checks
-- ============================================================
START TRANSACTION;

SELECT MIN(person_id) INTO @test_owner_id FROM owner;
SELECT MIN(person_id) INTO @test_agent_id FROM agent;
SELECT MIN(person_id) INTO @test_tenant_id FROM tenant;
SELECT MIN(account_id) INTO @test_admin_account_id FROM user_account
WHERE actor_role='ADMIN' AND is_active=TRUE;

INSERT INTO property
    (title, address, property_type, listing_type, asking_price, status, owner_id, agent_id)
VALUES
    ('Test rollback', 'Test rollback address', 'RESIDENTIAL', 'FOR_RENT',
     10000000.00, 'AVAILABLE', @test_owner_id, @test_agent_id);
SET @test_property_id = LAST_INSERT_ID();

INSERT INTO residential_property
    (property_id, bedrooms, bathrooms, area_sqm, furnished_status)
VALUES
    (@test_property_id, 2, 1, 65.00, 'UNFURNISHED');

INSERT INTO lease
    (start_date, end_date, monthly_rent, deposit_amount, payment_day,
     status, property_id, tenant_id, agent_id)
VALUES
    (CURRENT_DATE, DATE_ADD(CURRENT_DATE, INTERVAL 1 YEAR), 10000000.00,
     10000000.00, 5, 'PENDING', @test_property_id,
     @test_tenant_id, @test_agent_id);
SET @test_lease_id = LAST_INSERT_ID();

-- C0: Property and lease before activation.
SELECT p.property_id, p.status AS property_status,
       l.lease_id, l.status AS lease_status
FROM property p
JOIN lease l ON l.property_id = p.property_id
WHERE p.property_id = @test_property_id
  AND l.lease_id = @test_lease_id;

-- C1: Activate the lease; the property should become LEASED.
UPDATE lease SET status = 'ACTIVE',reviewed_by_account_id=@test_admin_account_id,reviewed_at=NOW()
WHERE lease_id = @test_lease_id;
SELECT p.property_id, p.status AS property_status,
       l.lease_id, l.status AS lease_status
FROM property p
JOIN lease l ON l.property_id = p.property_id
WHERE p.property_id = @test_property_id
  AND l.lease_id = @test_lease_id;

-- C2: Start maintenance; the property should become UNDER_MAINTENANCE.
INSERT INTO maintenance_request
    (lease_id, description, report_date, estimated_cost, status)
VALUES
    (@test_lease_id, 'Test rollback', CURRENT_DATE,
     500000.00, 'PENDING');
SET @test_request_id = LAST_INSERT_ID();
UPDATE maintenance_request SET status = 'IN_PROGRESS',
    reviewed_by_account_id = @test_admin_account_id, reviewed_at = NOW()
WHERE request_id = @test_request_id;
SELECT p.property_id, p.status AS property_status,
       m.request_id, m.status AS maintenance_status
FROM property p
JOIN lease l ON l.property_id = p.property_id
JOIN maintenance_request m ON m.lease_id = l.lease_id
WHERE p.property_id = @test_property_id
  AND m.request_id = @test_request_id;

-- C3: Complete maintenance while the lease is active; the property should return to LEASED.
UPDATE maintenance_request
SET status = 'COMPLETED', resolved_at = NOW(),
    reviewed_by_account_id = @test_admin_account_id, reviewed_at = NOW()
WHERE request_id = @test_request_id;
SELECT p.property_id, p.status AS property_status,
       m.request_id, m.status AS maintenance_status
FROM property p
JOIN lease l ON l.property_id = p.property_id
JOIN maintenance_request m ON m.lease_id = l.lease_id
WHERE p.property_id = @test_property_id
  AND m.request_id = @test_request_id;

-- C4: End the lease; with no active maintenance the property should become AVAILABLE.
UPDATE lease SET status = 'TERMINATED' WHERE lease_id = @test_lease_id;
SELECT p.property_id, p.status AS property_status,
       l.lease_id, l.status AS lease_status
FROM property p
JOIN lease l ON l.property_id = p.property_id
WHERE p.property_id = @test_property_id
  AND l.lease_id = @test_lease_id;

-- Roll back the temporary test data after capturing the results.
ROLLBACK;
SELECT COUNT(*) AS remaining_test_properties
FROM property WHERE title = 'Test rollback';

-- ============================================================
-- D: Try submitting a lease for a property listed for sale.
-- ============================================================
-- The INSERT should be rejected because a rental lease cannot use a FOR_SALE property.
-- After the error, run ROLLBACK before continuing.
START TRANSACTION;
SELECT MIN(person_id) INTO @test_tenant_id FROM tenant;
SELECT MIN(person_id) INTO @test_agent_id FROM agent;
SELECT MIN(account_id) INTO @test_admin_account_id FROM user_account
WHERE actor_role='ADMIN' AND is_active=TRUE;
SELECT MIN(property_id) INTO @test_sale_property_id
FROM property
WHERE listing_type = 'FOR_SALE' AND status = 'AVAILABLE';

INSERT INTO lease
    (start_date, end_date, monthly_rent, deposit_amount, payment_day,
     status, property_id, tenant_id, agent_id)
VALUES
    (CURRENT_DATE, DATE_ADD(CURRENT_DATE, INTERVAL 1 YEAR), 10000000.00,
     0, 5, 'PENDING', @test_sale_property_id,
     @test_tenant_id, @test_agent_id);
SET @test_bad_lease_id = LAST_INSERT_ID();
SELECT @test_sale_property_id AS for_sale_property_id,
       @test_bad_lease_id AS pending_lease_id;

-- After capturing the error, run: ROLLBACK;

-- ============================================================
-- E: Try to activate a second lease for the same property.
-- ============================================================
-- Run this after rolling back the previous test. Run one statement at a time.
-- The second activation should be rejected because the property is already LEASED;
-- uq_one_active_lease_per_property remains a final database backstop.
START TRANSACTION;
SELECT MIN(person_id) INTO @test_tenant_id FROM tenant;
SELECT MIN(person_id) INTO @test_agent_id FROM agent;
SELECT MIN(account_id) INTO @test_admin_account_id FROM user_account
WHERE actor_role='ADMIN' AND is_active=TRUE;
SELECT MIN(property_id) INTO @test_rental_property_id
FROM property
WHERE listing_type = 'FOR_RENT' AND status = 'AVAILABLE';

INSERT INTO lease
    (start_date, end_date, monthly_rent, deposit_amount, payment_day,
     status, property_id, tenant_id, agent_id)
VALUES
    (CURRENT_DATE, DATE_ADD(CURRENT_DATE, INTERVAL 1 YEAR), 10000000.00,
     0, 5, 'PENDING', @test_rental_property_id,
     @test_tenant_id, @test_agent_id);
SET @test_first_lease_id = LAST_INSERT_ID();

INSERT INTO lease
    (start_date, end_date, monthly_rent, deposit_amount, payment_day,
     status, property_id, tenant_id, agent_id)
VALUES
    (CURRENT_DATE, DATE_ADD(CURRENT_DATE, INTERVAL 1 YEAR), 10000000.00,
     0, 5, 'PENDING', @test_rental_property_id,
     @test_tenant_id, @test_agent_id);
SET @test_second_lease_id = LAST_INSERT_ID();

UPDATE lease SET status = 'ACTIVE',reviewed_by_account_id=@test_admin_account_id,reviewed_at=NOW()
WHERE lease_id = @test_first_lease_id;
SELECT @test_rental_property_id AS rental_property_id,
       @test_first_lease_id AS first_lease_id,
       @test_second_lease_id AS second_lease_id;

-- This update should be rejected because the first lease already made the property LEASED:
UPDATE lease SET status = 'ACTIVE',reviewed_by_account_id=@test_admin_account_id,reviewed_at=NOW()
WHERE lease_id = @test_second_lease_id;
-- After capturing the error, run: ROLLBACK;
