-- Tenant/Buyer actor profile
USE reims_db;

CREATE TABLE tenant (
    person_id BIGINT UNSIGNED PRIMARY KEY,
    id_card_number VARCHAR(30) NOT NULL UNIQUE,
    CONSTRAINT fk_tenant_person FOREIGN KEY (person_id) REFERENCES person(person_id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;
