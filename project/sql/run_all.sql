-- REIMS schema setup for the mysql command-line client (does not load demo rows).
-- MySQL Workbench does not run SOURCE directives: use README_VI.md and execute files one by one.
-- WARNING: 00_init.sql drops all current REIMS data. Create the first Admin, then load the seed separately.
SOURCE sql/00_init.sql;
SOURCE sql/ddl/actors/01_person.sql;
SOURCE sql/ddl/actors/02_user_account.sql;
SOURCE sql/ddl/actors/03_agent.sql;
SOURCE sql/ddl/actors/04_owner.sql;
SOURCE sql/ddl/actors/05_tenant.sql;
SOURCE sql/ddl/06_property.sql;
SOURCE sql/ddl/07_residential_property.sql;
SOURCE sql/ddl/08_commercial_property.sql;
SOURCE sql/ddl/09_lease.sql;
SOURCE sql/ddl/10_rental_invoice.sql;
SOURCE sql/ddl/11_payment.sql;
SOURCE sql/ddl/12_sale_transaction.sql;
SOURCE sql/ddl/13_maintenance_request.sql;
SOURCE sql/ddl/14_notification.sql;
SOURCE sql/triggers/01_account_roles.sql;
SOURCE sql/triggers/02_actor_profile_integrity.sql;
SOURCE sql/triggers/03_lease_property_status.sql;
SOURCE sql/triggers/04_payment_invoice.sql;
SOURCE sql/triggers/05_sale_workflow.sql;
SOURCE sql/triggers/06_maintenance_property_status.sql;
SOURCE sql/triggers/07_property_integrity.sql;
SOURCE sql/triggers/08_property_subtypes.sql;
SOURCE sql/views/01_property_dashboard.sql;
SOURCE sql/views/02_invoice_balance.sql;
SOURCE sql/views/03_overdue_invoices.sql;
SOURCE sql/procedures/01_generate_rental_invoices.sql;
SOURCE sql/procedures/02_refresh_notifications.sql;
SOURCE sql/procedures/03_property_admin_updates.sql;
