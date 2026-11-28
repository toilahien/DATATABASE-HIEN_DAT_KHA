-- Periodic rent invoices
USE reims_db;

CREATE TABLE rental_invoice (
    invoice_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    lease_id BIGINT UNSIGNED NOT NULL,
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    issue_date DATE NOT NULL,
    due_date DATE NOT NULL,
    amount_due DECIMAL(15,2) NOT NULL,
    amount_paid DECIMAL(15,2) NOT NULL DEFAULT 0,
    status ENUM('ISSUED','VOID') NOT NULL DEFAULT 'ISSUED',
    CONSTRAINT chk_invoice_period CHECK (period_end >= period_start),
    CONSTRAINT chk_invoice_due CHECK (due_date >= period_start),
    CONSTRAINT chk_invoice_amount CHECK (amount_due > 0),
    CONSTRAINT chk_invoice_paid CHECK (amount_paid >= 0 AND amount_paid <= amount_due),
    CONSTRAINT uq_invoice_lease_period UNIQUE (lease_id, period_start),
    CONSTRAINT fk_invoice_lease FOREIGN KEY (lease_id) REFERENCES lease(lease_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    INDEX ix_invoice_due (status, due_date),
    INDEX ix_invoice_lease (lease_id)
) ENGINE=InnoDB;
