# Real Estate Property & Rental Ledger System (REIMS)

Database Project Report — centralized relational database and management platform for small and medium-sized real estate brokerages / property management agencies.

## Team

| Field | Detail |
|---|---|
| **Team Name** | Hiền, Đạt, Kha |
| **Team Members** | Lại Thu Hiền · Lê Tuấn Kha · Nguyễn Thành Đạt |
| **Project Title** | Real Estate Property & Rental Ledger |

## Problem Statement

Small and medium-sized real estate brokerages and property management agencies that still rely on manual methods (physical records, spreadsheets, disconnected communication channels) face recurring operational problems: unsynchronized property statuses causing double bookings and conflicting transactions, scattered customer data, manual calculation errors in rent/commissions, and no automated alerts for expiring contracts or overdue payments.

**REIMS** addresses these problems through a centralized relational database covering property inventory, customer relationships, listings, viewings, leases, rental payments, maintenance requests, and financial information.

## Core Capabilities

- **Property Inventory Digitization & Synchronization** — centralized, real-time property status to prevent conflicting transactions
- **Centralized Customer Relationship Management (CRM)** — customer profiles, viewing schedules, consultation history
- **Contract & Financial Automation** — lease management, recurring billing, commission calculation, expiry/overdue notifications
- **Operational Data Visualization** — dashboards for occupancy, cash flow, property status, agent performance

## Actors

| Actor | Responsibilities |
|---|---|
| **Admin / Property Manager** | Manages property portfolio, agent allocation, approves contracts, controls financial ledger |
| **Agent (Broker / Operations)** | Manages assigned listings, coordinates viewings, prepares lease agreements, records maintenance requests |
| **Owner** | Monitors property status, contract history, maintenance events, payouts/revenue |
| **Tenant / Buyer** | Searches properties, books viewings, signs leases, makes payments, submits maintenance requests |

## Database Design (ISO/IEC 19505 / IE Standards)

### Conceptual Model (EER Diagram)

```mermaid
erDiagram
    PERSON ||--o| OWNER : ISA
    PERSON ||--o| TENANT : ISA
    PERSON ||--o| AGENT : ISA

    PERSON {
        int PersonID PK
        varchar FullName
        varchar Phone
        varchar Email
    }
    OWNER {
        int PersonID PK_FK
        varchar Address
    }
    TENANT {
        int PersonID PK_FK
        varchar IDCardNumber
    }
    AGENT {
        int PersonID PK_FK
        decimal CommissionRate
    }

    OWNER ||--o{ PROPERTY : owns
    AGENT ||--o{ PROPERTY : manages
    PROPERTY ||--|| RESIDENTIAL_PROPERTY : ISA
    PROPERTY ||--|| COMMERCIAL_PROPERTY : ISA

    PROPERTY {
        int PropertyID PK
        varchar Title
        varchar Address
        varchar PropertyType
        varchar ListingType "FOR_SALE / FOR_RENT"
        decimal Price
        varchar Status
        int OwnerID FK
        int AgentID FK
    }
    RESIDENTIAL_PROPERTY {
        int PropertyID PK_FK
        int Bedrooms
        int Bathrooms
        decimal Area
        varchar FurnishedStatus
    }
    COMMERCIAL_PROPERTY {
        int PropertyID PK_FK
        varchar BusinessType
        decimal FloorArea
        int ParkingSpaces
    }

    PROPERTY ||--o{ PROPERTY_IMAGE : has
    PROPERTY_IMAGE {
        int ImageID PK
        varchar ImageURL
        varchar Caption
        boolean IsPrimary
        date UploadedDate
        int PropertyID FK
    }

    PROPERTY ||--o{ VIEWING : has
    TENANT ||--o{ VIEWING : books
    AGENT ||--o{ VIEWING : handles
    VIEWING {
        int ViewingID PK
        date ViewingDate
        time ViewingTime
        varchar Status
        text Notes
        int PropertyID FK
        int TenantID FK
        int AgentID FK
    }

    PROPERTY ||--o{ LEASE : "leased via"
    TENANT ||--o{ LEASE : signs
    LEASE {
        int LeaseID PK
        date StartDate
        date EndDate
        decimal MonthlyRent
        decimal DepositAmount
        varchar Status
        int PropertyID FK
        int TenantID FK
    }

    LEASE ||--o{ PAYMENT : has
    PAYMENT {
        int PaymentID PK
        date PaymentDate
        decimal Amount
        varchar PaymentType
        varchar PaymentMethod
        int LeaseID FK
    }

    LEASE ||--o{ MAINTENANCE_REQUEST : submits
    MAINTENANCE_REQUEST {
        int RequestID PK
        text Description
        date ReportDate
        decimal EstimatedCost
        decimal ActualCost
        varchar Status
        int LeaseID FK
    }
```

### Entities Overview

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

## Key Business Rules

- **BR-01/02/03**: each property belongs to exactly one Owner; is listed as `FOR_SALE` or `FOR_RENT` (not both); status ∈ `{AVAILABLE, LEASED, UNDER_MAINTENANCE}`
- **BR-15**: a property may have multiple leases over its lifetime, but **at most one active lease** at a time
- **BR-16**: `EndDate > StartDate`, `MonthlyRent > 0`
- **BR-21/22**: financial records are never hard-deleted — full rental history is preserved per property
- **BR-24**: a property under maintenance cannot be leased

Full list (BR-01 → BR-24) is documented in the project report.

## Normalization

All 12 relations are verified against **1NF, 2NF, 3NF, and BCNF** — see Section 2.4 of the report for the functional-dependency analysis.

## Repository Contents

| File | Description |
|---|---|
| `Real Estate Rental Ledger - Full Report.docx` | Full project report: scope, requirements, business rules, EER diagram, data dictionary, logical schema, normalization |
| `Project progress report.docx` | Progress tracking document |

## Standards Referenced

- ISO/IEC 19505 (UML) / IE (Information Engineering) notation for conceptual modeling
- Elmasri & Navathe — *Fundamentals of Database Systems* (EER notation, Chapter 4)
