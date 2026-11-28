-- REIMS fresh-install reset. DESTRUCTIVE: removes all REIMS tables and data.
CREATE DATABASE IF NOT EXISTS reims_db CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE reims_db;

SET FOREIGN_KEY_CHECKS = 0;
DROP VIEW IF EXISTS v_overdue_invoices;
DROP VIEW IF EXISTS v_invoice_balance;
DROP VIEW IF EXISTS v_property_dashboard;
DROP TABLE IF EXISTS notification;
DROP TABLE IF EXISTS property_status_history; -- cleanup for an older schema version
DROP TABLE IF EXISTS maintenance_request;
DROP TABLE IF EXISTS sale_transaction;
DROP TABLE IF EXISTS payment;
DROP TABLE IF EXISTS rental_invoice;
DROP TABLE IF EXISTS lease;
DROP TABLE IF EXISTS commercial_property;
DROP TABLE IF EXISTS residential_property;
DROP TABLE IF EXISTS property;
DROP TABLE IF EXISTS tenant;
DROP TABLE IF EXISTS owner;
DROP TABLE IF EXISTS agent;
DROP TABLE IF EXISTS user_account;
DROP TABLE IF EXISTS person;
SET FOREIGN_KEY_CHECKS = 1;
