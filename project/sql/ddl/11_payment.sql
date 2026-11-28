-- Payment and refund ledger
USE reims_db;

CREATE TABLE payment (
    payment_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    lease_id BIGINT UNSIGNED NOT NULL,
    invoice_id BIGINT UNSIGNED NULL,
    payment_date DATE NOT NULL,
    amount DECIMAL(15,2) NOT NULL,
    payment_type ENUM('RENT','DEPOSIT','FEE','REFUND') NOT NULL DEFAULT 'RENT',
    payment_method ENUM('CASH','BANK_TRANSFER','CARD','E_WALLET','OTHER') NULL,
    reference_code VARCHAR(80) NULL UNIQUE,
    idempotency_key CHAR(36) NOT NULL UNIQUE,
    status ENUM('POSTED','REVERSED') NOT NULL DEFAULT 'POSTED',
    notes VARCHAR(255),
    CONSTRAINT chk_payment_amount CHECK (amount > 0),
    CONSTRAINT fk_payment_lease FOREIGN KEY (lease_id) REFERENCES lease(lease_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_payment_invoice FOREIGN KEY (invoice_id) REFERENCES rental_invoice(invoice_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    INDEX ix_payment_date (payment_date),
    INDEX ix_payment_lease (lease_id),
    INDEX ix_payment_invoice (invoice_id)
) ENGINE=InnoDB;
