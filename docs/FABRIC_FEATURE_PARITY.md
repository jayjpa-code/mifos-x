# Fabric / Mifos Feature Parity Matrix

Status values:
- `reference` — available in current Mifos channel and used as migration baseline
- `ui_prototype` — new Fabric UX exists but is not connected to live Fineract
- `api_wired` — connected to a live Fineract/BFF endpoint
- `verified` — lifecycle, validation, permission and error-state behaviour verified
- `not_started` — not yet implemented in the new channel

| Domain | Current Mifos reference | Fabric staff web | Customer mobile | Field officer | Wallet/Pay |
| --- | --- | --- | --- | --- | --- |
| Login / user context | Web App / Fineract | ui_prototype | reference | reference | reference |
| Role / permission navigation | Web App / Fineract | not_started | n/a | reference | reference |
| Dashboard | Web App | ui_prototype | n/a | reference | reference |
| Clients / Customer 360 | Web App | ui_prototype | reference | reference | reference |
| Groups | Web App | not_started | n/a | reference | n/a |
| Centers | Web App | not_started | n/a | reference | n/a |
| Offices / staff | Web App | not_started | n/a | reference | n/a |
| Savings accounts | Web App | not_started | reference | reference | reference |
| Savings products | Web App | not_started | n/a | n/a | n/a |
| Fixed deposits | Web App | not_started | reference where supported | reference where supported | n/a |
| Recurring deposits | Web App | not_started | reference where supported | reference where supported | n/a |
| Shares | Web App | not_started | n/a | reference where supported | n/a |
| Loan accounts | Web App | not_started | reference | reference | n/a |
| Loan products | Web App | not_started | n/a | n/a | n/a |
| Loan origination | Web App | not_started | reference/self-service scope | reference | n/a |
| Approval / disbursement | Web App | not_started | n/a | reference | n/a |
| Repayment / collection | Web App | not_started | reference | reference | n/a |
| Collection sheets | Web App | not_started | n/a | reference | n/a |
| Teller / cashier | Web App | not_started | n/a | n/a | n/a |
| Chart of accounts | Web App | not_started | n/a | n/a | n/a |
| Journal entries | Web App | not_started | n/a | n/a | n/a |
| Accounting rules | Web App | not_started | n/a | n/a | n/a |
| Maker-checker | Web App / Fineract | not_started | n/a | n/a | n/a |
| Users / roles / permissions | Web App / Fineract | not_started | n/a | n/a | n/a |
| Data tables / codes | Web App | not_started | n/a | n/a | n/a |
| Templates / hooks / external services | Web App | not_started | n/a | n/a | n/a |
| Scheduler jobs | Web App | not_started | n/a | n/a | n/a |
| Audit trail | Web App / Fineract | ui_prototype | n/a | n/a | n/a |
| Reports | Web App / Reporting plugin | not_started | n/a | n/a | n/a |
| Remittance | Web App when enabled | not_started | future | future | future |
| Interbank | Web App when enabled | not_started | future | future | future |
| Copilot | Web App when enabled | not_started | future | future | future |
| Offline field operations | Android field app | n/a | n/a | reference | n/a |
| Customer self-service | Mobile app / BFF | n/a | reference | n/a | reference |
| Wallet / merchant payment flows | Mifos Pay | n/a | future/integrated | n/a | reference |
| Payment orchestration / rails | Payment Hub EE | n/a | via BFF/Payment Hub | via backend | via Payment Hub |

## Exit criteria for retiring the legacy staff web

A staff-web domain can be declared `verified` only after:

1. Read/list/detail behaviour is proven against a real Fineract tenant.
2. Create/update/write workflows are mapped to real Fineract commands.
3. Product-driven fields come from backend templates/products rather than hard-coded frontend choices.
4. Backend validation errors are represented correctly in the UX.
5. Role and permission behaviour matches Fineract.
6. Maker-checker behaviour is preserved where enabled.
7. Auditability is confirmed.
8. Automated tests cover critical happy paths and permission/validation failures.
9. The matching legacy Web App workflow has been checked for any functional gaps.
