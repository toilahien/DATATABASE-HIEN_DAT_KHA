-- Shared property listing and ownership
USE reims_db;

CREATE TABLE property (
    property_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(150) NOT NULL,
    address VARCHAR(255) NOT NULL,
    property_type ENUM('RESIDENTIAL','COMMERCIAL') NOT NULL,
    listing_type ENUM('FOR_SALE','FOR_RENT') NOT NULL,
    asking_price DECIMAL(15,2) NOT NULL,
    status ENUM('AVAILABLE','LEASED','UNDER_MAINTENANCE','SOLD') NOT NULL DEFAULT 'AVAILABLE',
    owner_id BIGINT UNSIGNED NOT NULL,
    agent_id BIGINT UNSIGNED NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_property_price CHECK (asking_price > 0),
    CONSTRAINT fk_property_owner FOREIGN KEY (owner_id) REFERENCES owner(person_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_property_agent FOREIGN KEY (agent_id) REFERENCES agent(person_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    INDEX ix_property_search (listing_type, status, asking_price),
    INDEX ix_property_owner (owner_id),
    INDEX ix_property_agent (agent_id)
) ENGINE=InnoDB;
