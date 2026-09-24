Overview

The Real Estate Property & Rental Ledger System (REIMS) is designed to provide centralized management for small and medium-sized real estate brokerages and property management agencies.

Agencies operate a portfolio of properties that are owned by different clients, managed by different agents, and rented to different tenants. Property status, viewing schedules, lease contracts, and rental payments must stay consistent at all times.

In many cases, property records, viewing schedules, and rental payments are still managed manually using paper records or spreadsheets. This creates several problems:

Difficulty synchronizing property status, resulting in double bookings and conflicting transactions.
Difficulty tracing the complete financial and maintenance history of a property across multiple leases.
Lack of mandatory checks to ensure a property is never leased while unavailable or under maintenance.
Insufficient links between properties, owners, agents, tenants, leases, and rental payments.

The project addresses these problems by designing a relational database that integrates property inventory, ownership, agent allocation, viewings, leases, rental payments, and maintenance requests into one system.

Project Objective

The objective of this project is to design and build a relational database named Real Estate Property & Rental Ledger for the centralized management of:

Property inventory (residential and commercial)
Owners, agents, and tenants
Property viewings
Lease contracts
Rental payments
Maintenance requests

A key objective is to ensure that a property can have at most one active lease at any given time, and that property status is automatically synchronized whenever a lease becomes active, ends, or is terminated.

This rule will be enforced directly at the database layer using an SQL Trigger.

Project Scope
In Scope

The system includes the management of:

Persons (Owners, Tenants, Agents)
Properties (Residential, Commercial)
Property images
Property viewings
Lease contracts
Rental payments
Maintenance requests
Out of Scope

The following systems are not included:

Full accounting / general ledger for the brokerage company itself
Property sale conveyancing and legal title transfer processes
Marketing / lead-generation campaign automation
Human resources management of agency staff
Functional Requirements

The system must support the following functions:

FR1: An Admin/Property Manager can create, update, and manage property records, including type, location, ownership, listing type, and status.
FR2: An Admin/Property Manager can assign Agents responsible for specific properties.
FR3: An Agent can create and manage listings and viewings only for properties currently assigned to that Agent.
FR4: The system records every property viewing, including date, time, and status, and prevents overlapping confirmed viewings for the same Agent.
FR5: The system manages lease contracts, including start date, end date, rent, deposit, and status, and enforces at most one active lease per property.
FR6: The system automatically generates recurring rental payment records according to the lease payment schedule and tracks payment status.
FR7: The system records maintenance requests linked to a lease and updates property status accordingly.
FR8: The system supports reporting queries such as: property occupancy rate, cash flow by period, agent performance, leases nearing expiration, overdue payments.
Non-Functional Requirements
Security: Tenant and owner identification/contact information must have restricted access according to actor role.
Performance: Occupancy and cash-flow dashboard queries should return results promptly even as rental payment history grows.
Availability: The system should be available 24/7 so agents and tenants can check property status or book viewings at any time.
Data Integrity: Lease activation and property-status synchronization must be enforced at the database layer and must not rely entirely on application logic.
Business Rules
Property & Owner
BR-01: Each property is uniquely identified by a property_id and must be associated with exactly one Owner. An Owner may own multiple properties.
BR-02: Each property must be classified as either FOR_SALE or FOR_RENT when listed. A property cannot be simultaneously listed for both purposes.
BR-03: The property status must be constrained to AVAILABLE, LEASED, or UNDER_MAINTENANCE.
BR-04: A property can only be leased when its status is AVAILABLE. Once a lease becomes active, the property status must change to LEASED.
BR-05: A property with status UNDER_MAINTENANCE cannot be leased until the maintenance request has been completed.
Agent Allocation & Property Listing
BR-06: An Agent may manage multiple properties; a property may be assigned to one or more Agents over time.
BR-07: An Agent may only create or manage listings for properties currently assigned to that Agent.
BR-08: Each listing must contain property type, location, and applicable price.
BR-09: A property cannot have more than one conflicting active listing for the same transaction purpose.
Customer & Property Viewing
BR-10: Each Tenant is uniquely identified and must have at least one contact method.
BR-11: A Tenant may book multiple viewings; each viewing belongs to exactly one Tenant, one Property, and one Agent.
BR-12: A viewing can only be confirmed for a property whose status is AVAILABLE.
BR-13: A confirmed viewing cannot overlap with another confirmed viewing assigned to the same Agent.
Lease Management
BR-14: Each lease must reference exactly one Property and one Tenant.
BR-15: A property may have multiple lease records over its lifetime, but at most one active lease at any given time.
BR-16: MonthlyRent > 0 and EndDate > StartDate.
BR-17: A lease becomes active only after approval and the property is AVAILABLE.
BR-18: When a lease ends or is terminated, property status reverts from LEASED to AVAILABLE, unless placed under maintenance.
Rental Ledger & Financial History
BR-19: Each active lease may generate multiple rental payment records; each payment references exactly one lease.
BR-20: Amount > 0 for every payment.
BR-21: Payment records tied to completed/terminated leases must be retained — never hard-deleted.
BR-22: The ledger preserves complete financial history across multiple leases per property.
Maintenance Management
BR-23: A maintenance request must reference exactly one Lease and record description, report date, and status.
BR-24: When a property enters maintenance, status changes to UNDER_MAINTENANCE; it returns to AVAILABLE once completed, if no active lease exists.
Conceptual Database Design

The conceptual model contains the following main entities:

PERSON
OWNER
TENANT
AGENT
PROPERTY
RESIDENTIAL_PROPERTY
COMMERCIAL_PROPERTY
PROPERTY_IMAGE
VIEWING
LEASE
PAYMENT
MAINTENANCE_REQUEST

The EER design includes two specialization hierarchies:

PERSON
   |
   +-- OWNER
   |
   +-- TENANT
   |
   +-- AGENT
Overlapping: a person may simultaneously be an Owner, a Tenant, and/or an Agent.
Partial: a person may belong to none of the three subtypes.
PROPERTY
   |
   +-- RESIDENTIAL_PROPERTY
   |
   +-- COMMERCIAL_PROPERTY
Disjoint: a property cannot be both residential and commercial.
Total: every property must belong to exactly one subtype.
Entity Overview
Entity	Primary Key	Purpose
PERSON	PersonID	Common supertype for any individual in the system.
OWNER	PersonID	Owner subtype; owns one or more properties.
TENANT	PersonID	Tenant subtype; books viewings and signs leases.
AGENT	PersonID	Agent subtype; manages properties, viewings, and leases.
PROPERTY	PropertyID	Core property inventory record.
RESIDENTIAL_PROPERTY	PropertyID	Subtype; residential-specific attributes.
COMMERCIAL_PROPERTY	PropertyID	Subtype; commercial-specific attributes.
PROPERTY_IMAGE	ImageID	Photos associated with a property.
VIEWING	ViewingID	Scheduled property viewing between a Tenant and an Agent.
LEASE	LeaseID	Rental lease contract for a property.
PAYMENT	PaymentID	Rental ledger transaction tied to a lease.
MAINTENANCE_REQUEST	RequestID	Maintenance/repair tracking tied to a lease.
Relationship Summary
Relationship	Cardinality	Related Business Rule
OWNER — PROPERTY	1,1 – 0,N	BR-01
AGENT — PROPERTY	1,1 – 0,N	BR-06
PROPERTY — PROPERTY_IMAGE	1,1 – 0,N	—
PROPERTY — VIEWING	1,1 – 0,N	BR-12
TENANT — VIEWING	1,1 – 0,N	BR-11
AGENT — VIEWING	1,1 – 0,N	BR-11, BR-13
PROPERTY — LEASE	1,1 – 0,N	BR-15
TENANT — LEASE	1,1 – 0,N	BR-14
LEASE — PAYMENT	1,1 – 0,N	BR-19
LEASE — MAINTENANCE_REQUEST	1,1 – 0,N	BR-23
PERSON — OWNER/TENANT/AGENT	Overlapping, partial specialization	—
PROPERTY — RESIDENTIAL/COMMERCIAL	Disjoint, total specialization	—
Design Assumptions
A property has at most one active lease at any time (BR-15); lease history is preserved, not overwritten.
PROPERTY.AgentID represents the currently assigned agent; historical agent reassignment is not tracked in Phase 1.
Every payment must reference an existing lease (PAYMENT.LeaseID is mandatory); one-time fees unrelated to any lease are out of scope for Phase 1.
Hazard-style tiered access is not applicable to this domain; instead, property Status acts as the primary state-gating attribute.
Database Challenge

The main database challenge of this project is enforcing that a property never has more than one active lease at a time, and that property status stays synchronized whenever a lease's state changes.

Before inserting or activating a record in LEASE, the database must check:

The referenced Property and Tenant exist.
The Property's current status is AVAILABLE.
No other LEASE record for the same PropertyID currently has Status = 'ACTIVE'.

The rule will be implemented using an SQL Trigger such as:

sql
BEFORE INSERT OR UPDATE ON LEASE

The trigger will reject any attempt to activate a lease that would create a conflicting active lease for the same property, and will automatically update PROPERTY.Status to LEASED or AVAILABLE accordingly.

Team Members

Team: Hiền, Đạt, Kha

Lại Thu Hiền
Lê Tuấn Kha
Nguyễn Thành Đạt

Course: [Insert Course Code]
Phase: Phase 1 – Conceptual Design
