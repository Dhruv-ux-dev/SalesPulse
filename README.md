# SalesPulse — Salesforce Lead & Opportunity Management

[![Salesforce CI](https://github.com/Dhruv-ux-dev/SalesPulse/actions/workflows/salesforce-validate.yml/badge.svg)](https://github.com/Dhruv-ux-dev/SalesPulse/actions/workflows/salesforce-validate.yml)

SalesPulse is a Salesforce DX app that helps a sales team qualify inbound leads, see the health of its pipeline at a glance, and enrich account data from an external company-data API.

**Stack:** Salesforce DX · Apex · Lightning Web Components · SOQL · Record-Triggered Flow · Queueable Apex · Named Credentials · Apex tests · GitHub Actions

<!--
  Add screenshots here after deploying to a Developer Edition org, e.g.
  ![Pipeline dashboard](docs/dashboard.png)
  ![Scored lead](docs/lead-score.png)
-->

## Features

- **Lead scoring and routing.** When a Lead is created, a record-triggered Flow calls a bulk-safe invocable Apex action. It scores the lead from 0–100 (Hot / Warm / Cold) and routes it to the `Sales_Inbound` queue.
- **Pipeline dashboard.** A Lightning Web Component shows open pipeline value, closed-won revenue, open opportunity count, win rate, and the 25 most recently updated opportunities.
- **Account enrichment.** A button on the Account record page queues a REST callout through a Named Credential and fills in description, phone and website.
- **Data model.** Lead score/rating fields, opportunity health and next-action fields, account enrichment status, and a `SalesPulse Activity` custom object related to Opportunity.
- **Guardrails.** Validation rules require an email or phone on Leads, and an amount on Closed Won opportunities.

## Architecture

```mermaid
flowchart LR
    L[New Lead] -->|after-save| F[Flow: Lead Auto Score and Assign]
    F -->|invocable| R[LeadRoutingAction.cls]
    R -->|score + owner| L2[(Lead: Score, Rating, Queue)]

    D[salesPulseDashboard LWC] -->|@wire, cacheable| C[SalesPulseDashboardController.cls]
    C -->|aggregate SOQL, USER_MODE| O[(Opportunity)]

    B[accountEnrichmentButton LWC] -->|imperative Apex| E[AccountEnrichmentService.cls<br/>Queueable]
    E -->|callout:CompanyData| API[(Company Data REST API)]
    E -->|update as user| A[(Account)]
```

## Design decisions

| Decision | Why |
|---|---|
| Flow + invocable Apex instead of an Apex trigger | Admins can see and switch off the automation declaratively; the scoring logic stays in testable Apex. |
| Bulk-safe invocable method | Flow batches records, so the action collects all IDs, runs one query and one DML, and stays well inside governor limits on data loads. |
| Queue looked up by `DeveloperName` | No hard-coded record IDs, so the same code works in every sandbox and org. |
| Queueable Apex for callouts | Callouts can't run in the same transaction as the button's DML; Queueable runs them asynchronously and processes accounts in chunks of 50, chaining the rest. |
| Named Credential for the endpoint | The URL and authentication live in Setup, not in code or Git. |
| `with sharing` + `WITH USER_MODE` / `update as user` | Users only see and change records and fields their permissions allow. |
| `cacheable=true` on the dashboard method | Lightning Data Service caches the result; the refresh button calls `refreshApex` for fresh data. |

## Lead score model

The scoring model is rule-based and easy to change in `LeadRoutingAction.calculateScore`:

| Signal | Points |
|---|---|
| Priority industry (Technology, Finance, Healthcare, Manufacturing) | 20 |
| Annual revenue ≥ $1M / ≥ $250K | 20 / 10 |
| Employees ≥ 200 / ≥ 50 | 15 / 10 |
| Has email | 10 |
| Has website | 10 |
| Lead source Partner/Referral / Web | 15 / 10 |

The total is capped at 100. **Hot** is 70+, **Warm** is 40–69, **Cold** is below 40.

## Testing

Apex tests cover:

- **Scoring logic:** exact point totals for high- and zero-signal leads.
- **Bulk routing:** several leads processed through the invocable action in one call.
- **Dashboard metrics:** pipeline, closed-won, open count and win rate against known data.
- **REST callouts:** success and failure responses using `HttpCalloutMock`, plus domain parsing.

GitHub Actions runs static checks (well-formed metadata XML, a test class for every Apex class) on every push. When the `SF_AUTH_URL` repository secret is set, it also validates the deployment and runs all Apex tests against a real org.

## Deploy

Prerequisites: [Salesforce CLI](https://developer.salesforce.com/tools/salesforcecli) (`sf`) and a free [Developer Edition org](https://developer.salesforce.com/signup).

```bash
sf org login web --alias salespulse-dev --set-default
sf project deploy start --manifest manifest/package.xml --target-org salespulse-dev
sf apex run test --target-org salespulse-dev --test-level RunLocalTests --code-coverage --result-format human --wait 30
```

### Post-deployment setup

1. **Queue:** in Setup → Queues → *Sales Inbound*, add the sales reps who should receive new leads.
2. **Named Credential:** in Setup → Named Credentials → *CompanyData*, replace the placeholder URL (`https://api.example.com`) with your company-data provider and configure its authentication.
3. **Lightning pages:** in Lightning App Builder, add *SalesPulse Dashboard* to a Home or App page and *Account Enrichment Button* to the Account record page.
4. **Permissions:** grant sales users access to the Apex classes and custom fields through a permission set.

### Enable CI against your org

```bash
sf org display --target-org salespulse-dev --verbose --json
```

Copy the `sfdxAuthUrl` value into a repository secret named `SF_AUTH_URL` (GitHub → Settings → Secrets and variables → Actions).

## REST enrichment contract

`AccountEnrichmentService` calls:

```text
GET callout:CompanyData/v1/company?domain=<encoded-domain>
```

It expects JSON with optional `description`, `phone` and `website` strings. A non-2xx response or an exception sets `Enrichment_Status__c` to `Failed`, without logging customer data.

## Project layout

```text
force-app/main/default/
  classes/          Apex services, controllers and tests
  flows/            Record-triggered lead routing Flow
  lwc/              Pipeline dashboard and Account enrichment button
  objects/          Custom fields, custom object, validation rules
  queues/           Sales_Inbound queue
  namedCredentials/ CompanyData Named Credential
manifest/package.xml
.github/workflows/  CI pipeline
```

## License

MIT — see `LICENSE`.
