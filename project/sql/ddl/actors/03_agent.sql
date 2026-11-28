-- Agent actor profile
USE reims_db;

CREATE TABLE agent (
    person_id BIGINT UNSIGNED PRIMARY KEY,
    commission_rate DECIMAL(5,2) NOT NULL,
    CONSTRAINT chk_agent_commission CHECK (commission_rate BETWEEN 0 AND 100),
    CONSTRAINT fk_agent_person FOREIGN KEY (person_id) REFERENCES person(person_id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;
