# ERP Competitive Baseline

Updated: 2026-04-09 UTC
Method: official vendor product/help pages reviewed at a high level; no tenant hands-on validation in this run
Confidence: moderate

## 1. Comparison frame

Competitors tracked:
- Microsoft Dynamics 365 Business Central
- Oracle NetSuite
- SAP Business One
- Odoo
- Zoho finance/operations ecosystem

Evaluation focus:
- document workflows
- sales, purchasing, inventory
- customer/vendor management
- approvals/statuses
- reporting and accounting boundaries
- desktop usability
- mobile usability
- admin/setup practicality
- roles/permissions
- SMB onboarding practicality

## 2. Current baseline

| Product | Desktop usability | Mobile usability | Document workflow maturity | Approvals/status | Admin/setup practicality | SMB fit vs EBS Lite target |
|---|---|---|---|---|---|---|
| Business Central | strong browser-first back office | good mobile support, especially review/approval style usage | strong transactional document backbone | mature workflows/approvals | heavier than lightweight SMB tools, but structured | high benchmark for disciplined SMB operations |
| NetSuite | strong and broad browser ERP | mobile exists, but breadth and admin complexity are heavier | very strong breadth | mature role-driven governance | setup and ownership overhead are higher | benchmark for breadth, not for lightweight SMB simplicity |
| SAP Business One | strong classic ERP desktop/operational posture | mobile support exists but is not the primary value story | strong operational documents | solid approvals/status tracking | more partner-led and heavier to shape | benchmark for operational rigor and dense desktop work |
| Odoo | very strong browser modularity | mobile story is more mixed/module-dependent | broad and configurable | approvals/access rights are strong but vary by app stack | approachable for SMBs with admin effort | strong benchmark for modular browser productivity |
| Zoho ecosystem | strong SMB admin simplicity | very strong mobile and SMB onboarding ergonomics | good finance/inventory docs, but more fragmented across products | practical approvals/roles in product-specific scope | easiest onboarding of the group | benchmark for SMB ease and mobile practicality |

## 3. Practical takeaways for EBS Lite

EBS Lite should target this position:
- denser and more operationally efficient than Zoho on desktop
- easier and lighter for SMB rollout than NetSuite or SAP Business One
- more mobile-capable and offline-capable than browser-first suites
- clearer document workbench behavior across modules, closer to the best Business Central/Odoo-style back-office discipline

Verified repo implication:
- the strongest differentiator already visible in repo code is Flutter-first operational speed plus offline foundations
- the biggest current weakness versus competitors is inconsistent document workflow standardization across modules

## 4. Opportunity gaps

High-value opportunities:
- standardize document list/create/detail flows across purchases, sales detail, accounts, and customer/supplier workbenches
- keep desktop pages dense and review-oriented instead of stretched mobile cards
- preserve mobile speed and touch friendliness in create/approve flows
- explicitly classify web shell ownership so it does not drift into an unsupported parity claim

Competitive cautions:
- do not over-claim enterprise governance breadth against NetSuite or SAP Business One
- do not ignore browser-first back-office expectations established by Business Central and Odoo
- do not sacrifice the repo’s offline/mobile advantage by forcing every workflow into a browser-first shape

## 5. Refresh mechanism

Refresh triggers:
- start of a new milestone that changes scope or UX ownership
- before any major release candidate
- when the web shell becomes more customer-facing
- at least quarterly if the release program remains open

Refresh checklist:
1. Re-read this document plus `docs/inspection/DOCUMENT_WORKFLOW_STANDARD.md`.
2. Re-check official vendor pages for:
   - approvals/workflow changes
   - mobile positioning
   - finance/accounting positioning
   - SMB packaging or onboarding changes
3. Update the comparison table only where the source changed or the previous claim was unverified.
4. Record the refresh in `docs/inspection/EXECUTION_LEDGER.md`.

## 6. Official source set used for this baseline

- Microsoft Dynamics 365 Business Central:
  - https://www.microsoft.com/en-us/dynamics-365/solutions/small-business
  - https://learn.microsoft.com/en-us/dynamics365/business-central/product-requirements
- Oracle NetSuite:
  - https://www.netsuite.com/portal/products/erp.shtml
- SAP Business One:
  - https://www.sap.com/products/erp/business-one.html
- Odoo:
  - https://www.odoo.com/documentation/18.0/applications/general/users/access_rights.html
  - https://www.odoo.com/documentation/18.0/applications/inventory_and_mrp/purchase.html
  - https://www.odoo.com/documentation/18.0/applications/sales/sales.html
- Zoho:
  - https://www.zoho.com/us/books/help/workflow-rules/approvals.html
  - https://www.zoho.com/us/inventory/mobile-app/
  - https://www.zoho.com/us/books/help/settings/users-and-roles.html
