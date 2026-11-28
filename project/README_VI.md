# REIMS — Real Estate Property & Rental Ledger

REIMS is a MySQL 8 and Flask project for property listings, leases, rent invoices and payments, sales and commissions, maintenance, and notifications.

## Project layout

- `sql/ddl/`: table definitions, one table per file; actor profiles are in `sql/ddl/actors/`.
- `sql/triggers/`, `sql/views/`, `sql/procedures/`: database logic split by topic.
- `sql/seed/`: demo dataset with more than 4,000 rows.
- `sql/queries/`: individual sample queries grouped by topic.
- `ui/`: Flask web interface and launch scripts.

Admin is represented by `user_account.actor_role='ADMIN'`; there is no separate Admin business-profile table.

## Database setup

See [`sql/README_VI.md`](sql/README_VI.md) for the complete ordered setup instructions. The schema setup resets the REIMS tables; create the first Admin through `/setup`, then optionally load demo rows. **The reset removes existing project data.**

## Run the UI

See [`ui/README_UI_VI.md`](ui/README_UI_VI.md). MySQL Server must be running and `reims_db` must already be initialized. The launch scripts are `ui/run_ui.sh` (Linux/macOS) and `ui/run_ui.bat` (Windows).
