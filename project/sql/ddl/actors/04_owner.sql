-- Owner actor profile
USE reims_db;

CREATE TABLE owner (
    person_id BIGINT UNSIGNED PRIMARY KEY,
    mailing_address VARCHAR(255) NOT NULL,
    CONSTRAINT fk_owner_person FOREIGN KEY (person_id) REFERENCES person(person_id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;
