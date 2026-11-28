-- Lease agreement and approval fields
USE reims_db;

CREATE TABLE lease (
    lease_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    monthly_rent DECIMAL(15,2) NOT NULL,
    deposit_amount DECIMAL(15,2) NOT NULL DEFAULT 0,
    deposit_paid DECIMAL(15,2) NOT NULL DEFAULT 0,
    payment_day TINYINT UNSIGNED NOT NULL DEFAULT 1,
    status ENUM('PENDING','ACTIVE','EXPIRED','TERMINATED','REJECTED') NOT NULL DEFAULT 'PENDING',
    property_id BIGINT UNSIGNED NOT NULL,
    tenant_id BIGINT UNSIGNED NOT NULL,
    agent_id BIGINT UNSIGNED NOT NULL,
    reviewed_by_account_id BIGINT UNSIGNED NULL,
    reviewed_at DATETIME NULL,
    active_property_id BIGINT UNSIGNED GENERATED ALWAYS AS (CASE WHEN status = 'ACTIVE' THEN property_id ELSE NULL END) STORED,
    CONSTRAINT chk_lease_dates CHECK (end_date > start_date),
    CONSTRAINT chk_lease_rent CHECK (monthly_rent > 0),
    CONSTRAINT chk_lease_deposit CHECK (deposit_amount >= 0),
    CONSTRAINT chk_lease_deposit_paid CHECK (deposit_paid >= 0 AND deposit_paid <= deposit_amount),
    CONSTRAINT chk_payment_day CHECK (payment_day BETWEEN 1 AND 28),
    CONSTRAINT uq_one_active_lease_per_property UNIQUE (active_property_id),
    CONSTRAINT fk_lease_property FOREIGN KEY (property_id) REFERENCES property(property_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_lease_tenant FOREIGN KEY (tenant_id) REFERENCES tenant(person_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_lease_agent FOREIGN KEY (agent_id) REFERENCES agent(person_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_lease_reviewer FOREIGN KEY (reviewed_by_account_id) REFERENCES user_account(account_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    INDEX ix_lease_dates_status (status, start_date, end_date),
    INDEX ix_lease_tenant (tenant_id)
) ENGINE=InnoDB;
