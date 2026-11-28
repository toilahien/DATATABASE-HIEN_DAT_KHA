-- Prevent ambiguous Actor profiles and profile deletion that invalidates accounts/history.
USE reims_db;
DELIMITER $$

DROP TRIGGER IF EXISTS trg_agent_profile_insert$$
CREATE TRIGGER trg_agent_profile_insert
BEFORE INSERT ON agent
FOR EACH ROW
BEGIN
    IF EXISTS (SELECT 1 FROM owner WHERE person_id = NEW.person_id)
       OR EXISTS (SELECT 1 FROM tenant WHERE person_id = NEW.person_id)
       OR EXISTS (SELECT 1 FROM user_account WHERE person_id = NEW.person_id AND actor_role <> 'AGENT') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'A person cannot combine Agent with Owner or Tenant/Buyer profiles';
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_agent_profile_update$$
CREATE TRIGGER trg_agent_profile_update
BEFORE UPDATE ON agent
FOR EACH ROW
BEGIN
    IF NEW.person_id <> OLD.person_id
       OR EXISTS (SELECT 1 FROM owner WHERE person_id = NEW.person_id)
       OR EXISTS (SELECT 1 FROM tenant WHERE person_id = NEW.person_id)
       OR EXISTS (SELECT 1 FROM user_account WHERE person_id = NEW.person_id AND actor_role <> 'AGENT') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Agent profile identity and actor type are immutable';
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_agent_profile_delete$$
CREATE TRIGGER trg_agent_profile_delete
BEFORE DELETE ON agent
FOR EACH ROW
BEGIN
    IF EXISTS (SELECT 1 FROM user_account WHERE person_id = OLD.person_id AND actor_role = 'AGENT') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Delete the Agent account before removing its profile';
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_owner_profile_insert$$
CREATE TRIGGER trg_owner_profile_insert
BEFORE INSERT ON owner
FOR EACH ROW
BEGIN
    IF EXISTS (SELECT 1 FROM agent WHERE person_id = NEW.person_id)
       OR EXISTS (SELECT 1 FROM tenant WHERE person_id = NEW.person_id)
       OR EXISTS (SELECT 1 FROM user_account WHERE person_id = NEW.person_id AND actor_role <> 'OWNER') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'A person cannot combine Owner with Agent or Tenant/Buyer profiles';
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_owner_profile_update$$
CREATE TRIGGER trg_owner_profile_update
BEFORE UPDATE ON owner
FOR EACH ROW
BEGIN
    IF NEW.person_id <> OLD.person_id
       OR EXISTS (SELECT 1 FROM agent WHERE person_id = NEW.person_id)
       OR EXISTS (SELECT 1 FROM tenant WHERE person_id = NEW.person_id)
       OR EXISTS (SELECT 1 FROM user_account WHERE person_id = NEW.person_id AND actor_role <> 'OWNER') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Owner profile identity and actor type are immutable';
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_owner_profile_delete$$
CREATE TRIGGER trg_owner_profile_delete
BEFORE DELETE ON owner
FOR EACH ROW
BEGIN
    IF EXISTS (SELECT 1 FROM user_account WHERE person_id = OLD.person_id AND actor_role = 'OWNER') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Delete the Owner account before removing its profile';
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_tenant_profile_insert$$
CREATE TRIGGER trg_tenant_profile_insert
BEFORE INSERT ON tenant
FOR EACH ROW
BEGIN
    IF EXISTS (SELECT 1 FROM agent WHERE person_id = NEW.person_id)
       OR EXISTS (SELECT 1 FROM owner WHERE person_id = NEW.person_id)
       OR EXISTS (SELECT 1 FROM user_account WHERE person_id = NEW.person_id AND actor_role <> 'TENANT_BUYER') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'A person cannot combine Tenant/Buyer with Agent or Owner profiles';
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_tenant_profile_update$$
CREATE TRIGGER trg_tenant_profile_update
BEFORE UPDATE ON tenant
FOR EACH ROW
BEGIN
    IF NEW.person_id <> OLD.person_id
       OR EXISTS (SELECT 1 FROM agent WHERE person_id = NEW.person_id)
       OR EXISTS (SELECT 1 FROM owner WHERE person_id = NEW.person_id)
       OR EXISTS (SELECT 1 FROM user_account WHERE person_id = NEW.person_id AND actor_role <> 'TENANT_BUYER') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Tenant profile identity and actor type are immutable';
    END IF;
END$$

DROP TRIGGER IF EXISTS trg_tenant_profile_delete$$
CREATE TRIGGER trg_tenant_profile_delete
BEFORE DELETE ON tenant
FOR EACH ROW
BEGIN
    IF EXISTS (SELECT 1 FROM user_account WHERE person_id = OLD.person_id AND actor_role = 'TENANT_BUYER')
       OR EXISTS (SELECT 1 FROM lease WHERE tenant_id = OLD.person_id)
       OR EXISTS (SELECT 1 FROM sale_transaction WHERE buyer_id = OLD.person_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Tenant profile is linked to an account or transaction history';
    END IF;
END$$
DELIMITER ;
