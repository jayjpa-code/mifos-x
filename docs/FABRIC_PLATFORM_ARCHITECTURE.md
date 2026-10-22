# KoreNXT Fabric Platform Architecture

## Objective

KoreNXT Fabric preserves the Mifos/Apache Fineract product footprint while replacing the staff-facing experience incrementally with a new Fabric UI/UX. Apache Fineract remains the banking system of record. No channel is allowed to implement a parallel ledger, product engine, loan schedule engine, or account state machine.

## Channel architecture

```text
                                    KORENXT FABRIC

 Staff / Branch Web        Customer Mobile         Field Officer          Wallet / Pay
 new Fabric Web UI         Mifos Mobile            Mifos Field Officer    Mifos Pay
 React/TypeScript          Kotlin Multiplatform    Kotlin Multiplatform   Kotlin
        |                         |                       |                    |
        |                         +-----------+-----------+--------------------+
        |                                     |
        |                           Consumer-facing BFF
        |                       auth / policy / audit boundary
        |                                     |
        +--------------------------+----------+
                                   |
                            Apache Fineract Core
                                   |
                         PostgreSQL tenant databases
                                   |
              +--------------------+---------------------+
              |                    |                     |
        Reporting Plugin       Payment Hub EE       Open Banking /
                                                   external integrations
```

## Core principles

1. **Fineract is authoritative.** Clients, groups, centers, accounts, loans, products, schedules, charges, GL, maker-checker, permissions, audit events and transaction rules are owned by Fineract.
2. **Staff web and consumer channels have different trust boundaries.** The staff application may use a secured staff-facing Fineract adapter/API route. Consumer-facing applications use the Apache Fineract Consumer-Facing BFF pattern so end-user apps never hold Fineract service credentials.
3. **Do not collapse the product suite into one web application.** Staff web, customer mobile, field/offline, wallet/payment and payment-hub capabilities remain separate deployable channels sharing the same core.
4. **Preserve the current Mifos Web App during migration.** `jayjpa-code/mifos-web-app` remains the functional reference and fallback until every required staff workflow is verified in the new Fabric Web UI.
5. **Permissions remain server-driven.** New navigation and actions must respect Fineract user, role, permission and maker-checker semantics.
6. **No frontend financial rules.** Product configuration, charges, schedules, accounting behaviour, eligibility/status transitions and validations come from backend configuration and APIs.

## Repositories / deployable units

| Unit | Purpose | Current / target source |
| --- | --- | --- |
| `mifos-x` | Fineract deployment foundation and shared infrastructure | `jayjpa-code/mifos-x` |
| Legacy staff web | Current complete Mifos staff functionality / parity baseline | `jayjpa-code/mifos-web-app` |
| Fabric staff web | New UI/UX, progressively wired to Fineract | Lovable project now; move to a dedicated GitHub repo for production source control |
| Customer mobile | Retail/mobile-banking channel | fork/track `openMF/mifos-mobile` |
| Field officer | Offline-first field operations | fork/track `openMF/mifos-x-field-officer-app` |
| Wallet / Pay | Wallet, merchant and payment reference channel | fork/track `openMF/mifos-pay` |
| Consumer BFF | Secure consumer-facing API boundary | track `apache/fineract-consumer-facing` |
| Reporting | Operational / regulatory reporting extension | track `openMF/mifos-reporting-plugin` |
| Payment Hub EE | Payment orchestration and real-time rail integration | track Mifos Payment Hub EE |

## Staff Web migration model

The new Fabric staff UI must use a service boundary:

```text
UI Components
     |
 BankingAPI interface
     |
 +----------------------+----------------------+
 |                                             |
MockBankingAPI                            FineractBankingAPI
(local/demo only)                         production adapter
                                               |
                                  Fineract REST/OpenAPI client
```

The mock adapter is removable. Production banking data must never be persisted into a Lovable/Supabase database.

## Fineract staff domains to preserve

- Dashboard and global search
- Clients / Customer 360
- Groups and Centers
- Offices / Staff
- Savings accounts and products
- Fixed deposits
- Recurring deposits
- Share products
- Loan accounts and products
- Loan application, approval, disbursement, repayment, schedules, collateral and charges where supported
- Collections / collection sheets
- Teller / cashier / cash management
- Accounting: chart of accounts, journals, accounting rules, accruals, closing entries and financial activities
- Product configuration: charges, rates, taxes, product mix and supporting reference data
- Users, roles and permissions
- Maker-checker / Checker Inbox & Tasks
- Data tables, codes, templates, entity mappings, hooks and external services
- Scheduler jobs
- Audit trail
- Reports / reporting integration
- Bulk/data import where supported
- Standing instructions, fund mapping and reassignment workflows where supported
- Notifications / campaigns where enabled
- Remittance, interbank and Copilot modules when enabled

## Deployment boundary

Production target:

```text
Internet / Bank Network
       |
 CDN / Reverse Proxy / WAF
       |
 +-----+------------------------------+
 |                                    |
Fabric Staff Web                 Consumer Apps
 |                                    |
Staff API route / adapter        Consumer-Facing BFF
 |                                    |
 +-------------------+----------------+
                     |
               Fineract Core
                     |
                 PostgreSQL
```

Secrets are server-side only. Browser/mobile builds may hold public configuration such as API base URL and tenant identifier, but never Fineract service passwords, database credentials, model keys or signing keys.

## Current infrastructure blocker

The existing Render `korenxt-fineract` service is configured on a 512 MiB service. Recorded deployments build successfully but fail at runtime, including out-of-memory termination. The shared backend must be made healthy before live multi-channel integration is treated as complete.

This integration branch intentionally does **not** change the paid compute/database plan. Infrastructure sizing and durable database changes require an explicit deployment decision before merging to `dev`.
