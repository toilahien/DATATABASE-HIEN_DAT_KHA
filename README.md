# Real Estate Property & Rental Ledger System (REIMS)

> Centralized relational database for small and medium-sized real estate brokerages and property management agencies — covering property inventory, customer relationships, viewings, leases, rental payments, and maintenance requests.

## Table of Contents

- [Overview](#overview)
- [Team](#team)
- [Problem Statement](#problem-statement)
- [Project Objective](#project-objective)
- [Project Scope](#project-scope)
- [Actors](#actors)
- [Non-Functional Requirements](#non-functional-requirements)
- [Business Rules](#business-rules)
- [Database Design](#database-design)
  - [Conceptual Model (EER Diagram)](#conceptual-model-eer-diagram)
  - [Entity Overview](#entity-overview)
  - [Relationship Summary](#relationship-summary)
  - [Normalization](#normalization)
- [Repository Structure](#repository-structure)
- [Standards Referenced](#standards-referenced)

## Overview

**REIMS** is designed to provide centralized management for real estate brokerages and property management agencies that currently rely on manual records or disconnected spreadsheets. The system digitizes property inventory, customer relationships, viewings, lease contracts, rental payments, and maintenance requests into a single, consistent relational database.

## Team

| Field | Detail |
|---|---|
| **Team Name** | Hiền, Đạt, Kha |
| **Team Members** | Lại Thu Hiền · Lê Tuấn Kha · Nguyễn Thành Đạt |
| **Project Title** | Real Estate Property & Rental Ledger |

## Problem Statement

Agencies that still rely on manual methods face recurring operational problems:

- Property status difficult to synchronize → double bookings, conflicting transactions
- Customer data scattered across records → incomplete interaction history, missed leads
- Manual rent/commission calculation → financial errors
- No automated alerts for expiring leases or overdue payments → delayed action

## Project Objective

Design and build a centralized relational database that:

- Maintains property information and synchronizes status **in real time**
- Manages customers, viewings, listings, and lease records
- Automates recurring rental billing and preserves complete financial history
- Reduces duplicate transactions and manual calculation errors

A key rule — **a property can have at most one active lease at any given time**, with property status automatically synchronized when a lease becomes active, ends, or is terminated — is enforced at the **database layer**.

## Project Scope

### In Scope
- Persons (Owner, Tenant, Agent)
- Properties (Residential, Commercial)
- Property images
- Property viewings
- Lease contracts
- Rental payments
- Maintenance requests

### Out of Scope
- Full accounting / general ledger for the brokerage itself
- Property sale conveyancing and legal title transfer
- Marketing / lead-generation automation
- Agency staff HR management

## Actors

| Actor | Responsibilities |
|---|---|
| **Admin / Property Manager** | Manages property portfolio, agent allocation, approves contracts, controls financial ledger |
| **Agent (Broker / Operations)** | Manages assigned listings, coordinates viewings, prepares lease agreements, records maintenance requests |
| **Owner** | Monitors property status, contract history, maintenance events, payouts/revenue |
| **Tenant | The customer who rents a property through the system. A Tenant may sign a lease, make recurring rental payments, and submit maintenance requests during the tenancy|

## Non-Functional Requirements

- **Security** — tenant/owner contact information access-restricted by actor role
- **Performance** — dashboard queries remain responsive as payment history grows
- **Availability** — system available 24/7
- **Data Integrity** — lease activation and property-status sync enforced at the database layer, not application logic alone

## Business Rules

<details>
<summary><strong>Property & Owner (BR-01 → BR-05)</strong></summary>

- **BR-01:** Each property belongs to exactly one Owner; an Owner may own multiple properties.
- **BR-02:** Each property is listed as `FOR_SALE` or `FOR_RENT` — never both simultaneously.
- **BR-03:** Property status ∈ `{AVAILABLE, LEASED, UNDER_MAINTENANCE}`.
- **BR-04:** A property can only be leased when `AVAILABLE`; becomes `LEASED` once the lease is active.
- **BR-05:** A property `UNDER_MAINTENANCE` cannot be leased until maintenance is completed.
</details>

<details>
<summary><strong>Agent Allocation & Listing (BR-06 → BR-09)</strong></summary>

- **BR-06:** An Agent may manage multiple properties; a property may be assigned to one or more Agents over time.
- **BR-07:** An Agent may only manage listings for properties currently assigned to them.
- **BR-08:** Each listing must contain property type, location, and price.
- **BR-09:** A property cannot have more than one conflicting active listing for the same purpose.
</details>

<details>
<summary><strong>Customer & Viewing (BR-10 → BR-13)</strong></summary>

- **BR-10:** Each Tenant is uniquely identified and has at least one contact method.
- **BR-11:** Each viewing belongs to exactly one Tenant, one Property, and one Agent.
- **BR-12:** A viewing can only be confirmed for a property whose status is `AVAILABLE`.
- **BR-13:** A confirmed viewing cannot overlap with another confirmed viewing for the same Agent.
</details>

<details>
<summary><strong>Lease Management (BR-14 → BR-18)</strong></summary>

- **BR-14:** Each lease references exactly one Property and one Tenant.
- **BR-15:** A property may have multiple leases over time, but **at most one active lease** at a time.
- **BR-16:** `MonthlyRent > 0`; `EndDate > StartDate`.
- **BR-17:** A lease becomes active only after approval and the property is `AVAILABLE`.
- **BR-18:** When a lease ends/terminates, property status reverts to `AVAILABLE` (unless placed under maintenance).
</details>

<details>
<summary><strong>Rental Ledger (BR-19 → BR-22)</strong></summary>

- **BR-19:** Each payment references exactly one lease.
- **BR-20:** `Amount > 0` for every payment.
- **BR-21:** Payment records are never hard-deleted, even after the lease ends.
- **BR-22:** Complete financial history is preserved across multiple leases per property.
</details>

<details>
<summary><strong>Maintenance (BR-23 → BR-24)</strong></summary>

- **BR-23:** A maintenance request references exactly one Lease and records description, report date, and status.
- **BR-24:** Property status becomes `UNDER_MAINTENANCE` on request creation; returns to `AVAILABLE` once completed (if no active lease exists).
</details>

## Database Design

Designed following **ISO/IEC 19505 (UML)** and **Information Engineering (IE)** notation.

### Conceptual Model (EER Diagram)

### Entity Overview

| # | Entity | Primary Key | Description |
|---|---|---|---|
| 1 | PERSON | PersonID | Supertype — basic identity of any person in the system |
| 2 | OWNER | PersonID (FK) | Property owner |
| 3 | TENANT | PersonID (FK) | Renter / lease signer |
| 4 | AGENT | PersonID (FK) | Broker handling listings, viewings, leases |
| 5 | PROPERTY | PropertyID | Property inventory record |
| 6 | RESIDENTIAL_PROPERTY | PropertyID (FK) | Subtype — residential-specific attributes |
| 7 | COMMERCIAL_PROPERTY | PropertyID (FK) | Subtype — commercial-specific attributes |
| 8 | PROPERTY_IMAGE | ImageID | Property photos |
| 9 | VIEWING | ViewingID | Scheduled property viewings |
| 10 | LEASE | LeaseID | Rental lease contract |
| 11 | PAYMENT | PaymentID | Rental ledger transactions |
| 12 | MAINTENANCE_REQUEST | RequestID | Maintenance/repair tracking |

### Relationship Summary

| Relationship | Cardinality | Related Business Rule |
|---|---|---|
| OWNER — PROPERTY | 1,1 – 0,N | BR-01 |
| AGENT — PROPERTY | 1,1 – 0,N | BR-06 |
| PROPERTY — PROPERTY_IMAGE | 1,1 – 0,N | — |
| PROPERTY — VIEWING | 1,1 – 0,N | BR-12 |
| TENANT — VIEWING | 1,1 – 0,N | BR-11 |
| AGENT — VIEWING | 1,1 – 0,N | BR-11, BR-13 |
| PROPERTY — LEASE | 1,1 – 0,N | BR-15 |
| TENANT — LEASE | 1,1 – 0,N | BR-14 |
| LEASE — PAYMENT | 1,1 – 0,N | BR-19 |
| LEASE — MAINTENANCE_REQUEST | 1,1 – 0,N | BR-23 |
| PERSON — OWNER/TENANT/AGENT | Overlapping, partial specialization | — |
| PROPERTY — RESIDENTIAL/COMMERCIAL | Disjoint, total specialization | — |

### Normalization

All 12 relations are verified against **1NF, 2NF, 3NF, and BCNF**. Every relation has a single-attribute primary key, so no partial or transitive dependency exists — see the full report for the functional-dependency analysis per relation.

## Repository Structure

```
.
├── DB_Project_Report.docx
├── EER Diagram.png
│                                                   
└── README.md                  # Full report: scope, requirements, business rules,
```

## Standards Referenced

- **ISO/IEC 19505** (UML) / **IE** (Information Engineering) notation for conceptual modeling
- Elmasri & Navathe — *Fundamentals of Database Systems* (EER notation, Chapter 4)
