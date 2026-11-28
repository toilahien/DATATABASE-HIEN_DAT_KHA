-- Sale workflow and commission snapshot
USE reims_db;

CREATE TABLE sale_transaction (
    sale_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    property_id BIGINT UNSIGNED NOT NULL,
    buyer_id BIGINT UNSIGNED NOT NULL,
    agent_id BIGINT UNSIGNED NOT NULL,
    sale_price DECIMAL(15,2) NOT NULL,
    commission_rate_at_sale DECIMAL(5,2) NOT NULL,
    status ENUM('PENDING','APPROVED','CLOSED','REJECTED','CANCELLED') NOT NULL DEFAULT 'PENDING',
    commission_amount DECIMAL(15,2) GENERATED ALWAYS AS
        (CASE WHEN status='CLOSED' THEN ROUND(sale_price * commission_rate_at_sale / 100, 2) ELSE 0 END) STORED,
    contract_date DATE NOT NULL,
    closing_date DATE NULL,
    reviewed_by_account_id BIGINT UNSIGNED NULL,
    reviewed_at DATETIME NULL,
    active_property_id BIGINT UNSIGNED GENERATED ALWAYS AS
        (CASE WHEN status IN ('PENDING','APPROVED') THEN property_id ELSE NULL END) STORED,
    CONSTRAINT chk_sale_price CHECK (sale_price > 0),
    CONSTRAINT chk_sale_commission_rate CHECK (commission_rate_at_sale BETWEEN 0 AND 100),
    CONSTRAINT chk_sale_closing_date CHECK (status <> 'CLOSED' OR closing_date IS NOT NULL),
    CONSTRAINT uq_sale_open_property UNIQUE (active_property_id),
    CONSTRAINT fk_sale_property FOREIGN KEY (property_id) REFERENCES property(property_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_sale_buyer FOREIGN KEY (buyer_id) REFERENCES tenant(person_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_sale_agent FOREIGN KEY (agent_id) REFERENCES agent(person_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    CONSTRAINT fk_sale_reviewer FOREIGN KEY (reviewed_by_account_id) REFERENCES user_account(account_id) ON DELETE RESTRICT ON UPDATE RESTRICT,
    INDEX ix_sale_status_date (status, contract_date),
    INDEX ix_sale_agent (agent_id)
) ENGINE=InnoDB;
