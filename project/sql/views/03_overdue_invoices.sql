-- Convenience view of overdue invoices with property context.
USE reims_db;
DROP VIEW IF EXISTS v_overdue_invoices;

CREATE VIEW v_overdue_invoices AS
SELECT b.*,l.tenant_id,l.agent_id,p.property_id,p.title
FROM v_invoice_balance b JOIN lease l ON l.lease_id=b.lease_id JOIN property p ON p.property_id=l.property_id
WHERE b.invoice_status='OVERDUE';
