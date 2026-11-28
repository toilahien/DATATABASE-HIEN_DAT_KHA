-- In-app notifications
USE reims_db;

CREATE TABLE notification (
    notification_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    account_id BIGINT UNSIGNED NOT NULL,
    notification_type ENUM('INVOICE_DUE','INVOICE_OVERDUE','LEASE_EXPIRING','LEASE_EXPIRED','SALE_UPDATE','SYSTEM') NOT NULL,
    dedupe_key VARCHAR(160) NOT NULL,
    title VARCHAR(150) NOT NULL,
    message VARCHAR(500) NOT NULL,
    invoice_id BIGINT UNSIGNED NULL,
    sale_id BIGINT UNSIGNED NULL,
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_notification_dedupe UNIQUE (account_id, dedupe_key),
    CONSTRAINT fk_notification_account FOREIGN KEY (account_id) REFERENCES user_account(account_id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_notification_invoice FOREIGN KEY (invoice_id) REFERENCES rental_invoice(invoice_id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_notification_sale FOREIGN KEY (sale_id) REFERENCES sale_transaction(sale_id) ON DELETE CASCADE ON UPDATE CASCADE,
    INDEX ix_notification_unread (account_id, is_read, created_at)
) ENGINE=InnoDB;
