# REIMS SQL files

This folder separates the database setup by object type and business area. The table definitions are intentionally split into individual files. Actor profiles are separate: Admin is a role in `user_account`; there is no separate `admin` table.

## Folder layout

```text
sql/
  00_init.sql                 Reset/create the REIMS schema (DESTRUCTIVE)
  run_all.sql                 Create/reset schema objects (seed is a separate step)
  ddl/actors/                 PERSON, USER_ACCOUNT, AGENT, OWNER, TENANT
  ddl/                       PROPERTY, subtypes, LEASE, invoice, payment, sale, maintenance, notification
  triggers/                   Actor profiles, lease, invoice/payment, sale, maintenance, property integrity
  views/                      Property dashboard and invoice balance views
  procedures/                 Invoice generation and notification refresh
  seed/01_data4000.sql         Coordinated demo data (4,000+ rows)
  queries/<topic>/             One query per file, grouped by topic
  tests/manual_status_checks.sql  Manual transaction and trigger checks
```

## Fresh setup in MySQL Workbench

Workbench does not execute MySQL client `SOURCE` commands. Open and run the following scripts in order. For files with multiple statements or `DELIMITER`, use **Execute SQL Script** (the lightning bolt / Run All), not only the current-statement shortcut.

1. `sql/00_init.sql` — drops current REIMS tables and recreates an empty database. Do not run if you need to keep existing data.
2. `sql/ddl/actors/01_person.sql`
3. `sql/ddl/actors/02_user_account.sql`
4. `sql/ddl/actors/03_agent.sql`
5. `sql/ddl/actors/04_owner.sql`
6. `sql/ddl/actors/05_tenant.sql`
7. `sql/ddl/06_property.sql`
8. `sql/ddl/07_residential_property.sql`
9. `sql/ddl/08_commercial_property.sql`
10. `sql/ddl/09_lease.sql`
11. `sql/ddl/10_rental_invoice.sql`
12. `sql/ddl/11_payment.sql`
13. `sql/ddl/12_sale_transaction.sql`
14. `sql/ddl/13_maintenance_request.sql`
15. `sql/ddl/14_notification.sql`
16. Run all files in `sql/triggers/` in numeric order (01 through 08).
17. Run all files in `sql/views/` in numeric order.
18. Run all files in `sql/procedures/` in numeric order.
19. After the schema objects are installed, start the UI and create the first Admin at `/setup`. Then run `sql/seed/01_data4000.sql` to load demo data. The seed simulates lease approvals using that active Admin account. Run the seed only once per fresh installation.

The first Admin login is created from the web app setup page; demo SQL seed data creates business actors and records, not an Admin password.

## Fresh setup from a terminal

From the project root, run `mysql -u root -p < sql/run_all.sql`. The `SOURCE` runner is for the MySQL command-line client; do not paste it into a Workbench query tab. It resets and creates the schema objects but does not insert demo data. Create the first Admin through the UI, then run `mysql -u root -p reims_db < sql/seed/01_data4000.sql` once if you want demo data.

## Queries and checks

- Run one report: open a file under `sql/queries/` (for example `sql/queries/finance/q16.sql`) and execute it.
- Run every report from the terminal: `mysql -u root -p < sql/queries/run_all_queries.sql`.
- Optional manual state-transition checks: `sql/tests/manual_status_checks.sql`. Read its comments and run the expected-error statements one at a time; it is not an automated test suite.

## Integrity rules enforced in SQL

- Leases, sales, and maintenance requests start in their request state; lease/sale review and maintenance status changes require an active Admin account. Terminal records cannot be reopened or deleted.
- Property status changes only through lease, sale, and maintenance workflows. Listing/Agent changes use validated stored procedures.
- Rental invoice balances and held deposits are maintained by payment triggers. Rent overpayment, excess deposit collection/refunds, exact duplicate payments, future-dated receipts, and edits/deletion of posted ledger rows are rejected.
- Sale commissions are calculated only when an approved sale closes; transaction terms are then immutable.

These triggers enforce data consistency; they do not authenticate the MySQL client. Review checks verify that the supplied reviewer account is an active Admin, but the current Flask setup uses one shared database login. Keep that database credential private; production deployments should use a restricted service account and keep actor authorization in the application.

## Existing database with data

Do not run `sql/00_init.sql` or `sql/run_all.sql` on a database whose data you need to preserve. Back up first, then run the one-time migration `sql/migrations/01_harden_existing_schema.sql`. After it succeeds, recreate triggers 01–08, views 01–03, and procedures 01–03 in numeric order. The migration carries posted rent receipts/refunds into invoice balances and posted deposits/refunds into lease deposit balances; it stops if those historical balances violate the allowed ranges. Do not run the migration twice.
