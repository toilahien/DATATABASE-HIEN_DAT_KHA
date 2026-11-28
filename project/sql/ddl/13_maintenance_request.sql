-- Maintenance requests tied to leases
USE reims_db;

CREATE TABLE maintenance_request (
    request_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    lease_id BIGINT UNSIGNED NOT NULL,
    description TEXT NOT NULL,
    report_date DATE NOT NULL,
    estimated_cost DECIMAL(15,2) NULL,
    actual_cost DECIMAL(15,2) NULL,
    status ENUM('PENDING','IN_PROGRESS','COMPLETED','CANCELLED') NOT NULL DEFAULT 'PENDING',
    resolved_at DATETIME NULL,
    reviewed_by_account_id BIGINT UNSIGNED NULL,
    reviewed_at DATETIME NULL,
    CONSTRAINT chk_maintenance_estimate CHECK (estimated_cost IS NULL OR estimated_cost >= 0),
    CONSTRAINT chk_maintenance_actual CHECK (actual_cost IS NULL OR actual_cost >= 0),
    CONSTRAINT fk_maintenance_lease FOREIGN KEY (lease_id) REFERENCES lease(lease_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_maintenance_reviewer FOREIGN KEY (reviewed_by_account_id) REFERENCES user_account(account_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    INDEX ix_maintenance_status (status, report_date),
    INDEX ix_maintenance_lease (lease_id)
) ENGINE=InnoDB;
