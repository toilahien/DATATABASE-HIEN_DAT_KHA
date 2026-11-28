-- Database-level role/profile consistency for login accounts.
USE reims_db;
DELIMITER $$

DROP TRIGGER IF EXISTS trg_account_role_insert$$
CREATE TRIGGER trg_account_role_insert
BEFORE INSERT ON user_account
FOR EACH ROW
BEGIN
    IF (NEW.actor_role = 'ADMIN' AND NEW.person_id IS NOT NULL)
       OR (NEW.actor_role <> 'ADMIN' AND NEW.person_id IS NULL) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Admin accounts must not link a person; other accounts must link one';
    ELSEIF NEW.actor_role = 'AGENT' AND (
        NOT EXISTS (SELECT 1 FROM agent WHERE person_id = NEW.person_id)
        OR EXISTS (SELECT 1 FROM owner WHERE person_id = NEW.person_id)
        OR EXISTS (SELECT 1 FROM tenant WHERE person_id = NEW.person_id)
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Agent accounts require an Agent-only profile';
    ELSEIF NEW.actor_role = 'OWNER' AND (
        NOT EXISTS (SELECT 1 FROM owner WHERE person_id = NEW.person_id)
        OR EXISTS (SELECT 1 FROM agent WHERE person_id = NEW.person_id)
        OR EXISTS (SELECT 1 FROM tenant WHERE person_id = NEW.person_id)
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Owner accounts require an Owner-only profile';
    ELSEIF NEW.actor_role = 'TENANT_BUYER' AND (
        NOT EXISTS (SELECT 1 FROM tenant WHERE person_id = NEW.person_id)
        OR EXISTS (SELECT 1 FROM owner WHERE person_id = NEW.person_id)
        OR EXISTS (SELECT 1 FROM agent WHERE person_id = NEW.person_id)
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Tenant/Buyer accounts require a Tenant-only profile';
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_account_role_update$$
CREATE TRIGGER trg_account_role_update
BEFORE UPDATE ON user_account
FOR EACH ROW
BEGIN
    IF (NEW.actor_role = 'ADMIN' AND NEW.person_id IS NOT NULL)
       OR (NEW.actor_role <> 'ADMIN' AND NEW.person_id IS NULL) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Admin accounts must not link a person; other accounts must link one';
    ELSEIF NEW.actor_role = 'AGENT' AND (
        NOT EXISTS (SELECT 1 FROM agent WHERE person_id = NEW.person_id)
        OR EXISTS (SELECT 1 FROM owner WHERE person_id = NEW.person_id)
        OR EXISTS (SELECT 1 FROM tenant WHERE person_id = NEW.person_id)
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Agent accounts require an Agent-only profile';
    ELSEIF NEW.actor_role = 'OWNER' AND (
        NOT EXISTS (SELECT 1 FROM owner WHERE person_id = NEW.person_id)
        OR EXISTS (SELECT 1 FROM agent WHERE person_id = NEW.person_id)
        OR EXISTS (SELECT 1 FROM tenant WHERE person_id = NEW.person_id)
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Owner accounts require an Owner-only profile';
    ELSEIF NEW.actor_role = 'TENANT_BUYER' AND (
        NOT EXISTS (SELECT 1 FROM tenant WHERE person_id = NEW.person_id)
        OR EXISTS (SELECT 1 FROM owner WHERE person_id = NEW.person_id)
        OR EXISTS (SELECT 1 FROM agent WHERE person_id = NEW.person_id)
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Tenant/Buyer accounts require a Tenant-only profile';
    END IF;
END$$
DELIMITER ;
