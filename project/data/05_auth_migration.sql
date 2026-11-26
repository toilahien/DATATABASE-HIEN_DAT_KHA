-- Non-destructive upgrade for an existing REIMS database.
-- Adds login accounts and lease review metadata without dropping project data.
USE reims_db;

CREATE TABLE IF NOT EXISTS user_account (
    account_id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(80) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    actor_role ENUM('ADMIN','AGENT','OWNER','TENANT_BUYER') NOT NULL,
    person_id BIGINT UNSIGNED NULL UNIQUE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_account_person FOREIGN KEY (person_id) REFERENCES person(person_id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- Remove this old check if a previous attempt created the table before failing later.
SET @has_account_role_check = (
    SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS
    WHERE CONSTRAINT_SCHEMA=DATABASE() AND TABLE_NAME='user_account'
      AND CONSTRAINT_NAME='chk_account_person_role' AND CONSTRAINT_TYPE='CHECK'
);
SET @account_role_check_sql = IF(
    @has_account_role_check>0,
    'ALTER TABLE user_account DROP CHECK chk_account_person_role',
    'SELECT 1'
);
PREPARE account_role_check_stmt FROM @account_role_check_sql;
EXECUTE account_role_check_stmt;
DEALLOCATE PREPARE account_role_check_stmt;

SET @has_reviewer_column = (
    SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='lease' AND COLUMN_NAME='reviewed_by_account_id'
);
SET @reviewer_column_sql = IF(
    @has_reviewer_column=0,
    'ALTER TABLE lease ADD COLUMN reviewed_by_account_id BIGINT UNSIGNED NULL',
    'SELECT 1'
);
PREPARE reviewer_column_stmt FROM @reviewer_column_sql;
EXECUTE reviewer_column_stmt;
DEALLOCATE PREPARE reviewer_column_stmt;

SET @has_reviewed_at_column = (
    SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA=DATABASE() AND TABLE_NAME='lease' AND COLUMN_NAME='reviewed_at'
);
SET @reviewed_at_column_sql = IF(
    @has_reviewed_at_column=0,
    'ALTER TABLE lease ADD COLUMN reviewed_at DATETIME NULL',
    'SELECT 1'
);
PREPARE reviewed_at_column_stmt FROM @reviewed_at_column_sql;
EXECUTE reviewed_at_column_stmt;
DEALLOCATE PREPARE reviewed_at_column_stmt;

SET @has_lease_reviewer_fk = (
    SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS
    WHERE CONSTRAINT_SCHEMA=DATABASE() AND TABLE_NAME='lease'
      AND CONSTRAINT_NAME='fk_lease_reviewer' AND CONSTRAINT_TYPE='FOREIGN KEY'
);
SET @lease_reviewer_fk_sql = IF(
    @has_lease_reviewer_fk=0,
    'ALTER TABLE lease ADD CONSTRAINT fk_lease_reviewer FOREIGN KEY (reviewed_by_account_id) REFERENCES user_account(account_id) ON DELETE RESTRICT ON UPDATE CASCADE',
    'SELECT 1'
);
PREPARE lease_reviewer_fk_stmt FROM @lease_reviewer_fk_sql;
EXECUTE lease_reviewer_fk_stmt;
DEALLOCATE PREPARE lease_reviewer_fk_stmt;

DELIMITER $$
DROP TRIGGER IF EXISTS trg_account_role_insert$$
CREATE TRIGGER trg_account_role_insert
BEFORE INSERT ON user_account
FOR EACH ROW
BEGIN
    IF (NEW.actor_role='ADMIN' AND NEW.person_id IS NOT NULL) OR
       (NEW.actor_role<>'ADMIN' AND NEW.person_id IS NULL) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Admin accounts must not link a person; other accounts must link one';
    ELSEIF NEW.actor_role='AGENT' AND NOT EXISTS (SELECT 1 FROM agent WHERE person_id=NEW.person_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Agent account must link to an Agent profile';
    ELSEIF NEW.actor_role='OWNER' AND NOT EXISTS (SELECT 1 FROM owner WHERE person_id=NEW.person_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Owner account must link to an Owner profile';
    ELSEIF NEW.actor_role='TENANT_BUYER' AND (
        EXISTS (SELECT 1 FROM owner WHERE person_id=NEW.person_id) OR
        EXISTS (SELECT 1 FROM agent WHERE person_id=NEW.person_id)
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Tenant/Buyer account cannot link to an Owner or Agent profile';
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_account_role_update$$
CREATE TRIGGER trg_account_role_update
BEFORE UPDATE ON user_account
FOR EACH ROW
BEGIN
    IF (NEW.actor_role='ADMIN' AND NEW.person_id IS NOT NULL) OR
       (NEW.actor_role<>'ADMIN' AND NEW.person_id IS NULL) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Admin accounts must not link a person; other accounts must link one';
    ELSEIF NEW.actor_role='AGENT' AND NOT EXISTS (SELECT 1 FROM agent WHERE person_id=NEW.person_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Agent account must link to an Agent profile';
    ELSEIF NEW.actor_role='OWNER' AND NOT EXISTS (SELECT 1 FROM owner WHERE person_id=NEW.person_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Owner account must link to an Owner profile';
    ELSEIF NEW.actor_role='TENANT_BUYER' AND (
        EXISTS (SELECT 1 FROM owner WHERE person_id=NEW.person_id) OR
        EXISTS (SELECT 1 FROM agent WHERE person_id=NEW.person_id)
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Tenant/Buyer account cannot link to an Owner or Agent profile';
    END IF;
END$$
DELIMITER ;
