-- Login accounts for Admin, Agent, Owner, and Tenant/Buyer. Admin is a role in this table, not a separate table.
USE reims_db;

CREATE TABLE user_account (
    account_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(80) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    actor_role ENUM('ADMIN','AGENT','OWNER','TENANT_BUYER') NOT NULL,
    person_id BIGINT UNSIGNED NULL UNIQUE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_account_person FOREIGN KEY (person_id) REFERENCES person(person_id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;
