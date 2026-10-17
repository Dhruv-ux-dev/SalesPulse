# SalesPulse — Salesforce Lead & Opportunity Management

SalesPulse is a Salesforce DX sample project for lead qualification, pipeline visibility, and account enrichment. It is intended to be deployed to a Salesforce Developer Edition or sandbox org and then customized for your sales process.

## Features

- **Lead scoring and routing:** a record-triggered Flow invokes bulk-safe Apex to score new leads and route them to the `Sales_Inbound` queue when that queue exists.
- **Pipeline dashboard:** a Lightning Web Component shows open pipeline value, closed-won revenue, open opportunity count, win rate, and a recent-opportunity table.
- **Account enrichment:** an Account record-page action queues a REST callout using a Named Credential and updates account enrichment fields.
- **Data model:** lead score/rating fields, opportunity health and next-action fields, account enrichment status, and a related `SalesPulse Activity` custom object.
- **Guardrails:** validation rules for a lead contact method and positive amount on Closed Won opportunities.
- **Automated tests:** Apex tests cover the scoring logic, dashboard metrics, and successful/failed callout behavior.

## Tech stack

Salesforce DX · Apex · Lightning Web Components · SOQL · Record-Triggered Flow · Queueable Apex · Named Credentials · Apex tests

## Prerequisites

- Salesforce CLI (`sf`)
- A Salesforce Developer Edition org or sandbox with permissions to deploy metadata
- A user with access to create custom metadata, Apex classes, flows, Lightning Web Components, queues, and Named Credentials

## Publish to GitHub

Create a **new, empty** repository named `SalesPulse` on GitHub (leave the README, license, and `.gitignore` options unchecked). From the extracted project folder, run:

```bash
./scripts/push-to-github.sh https://github.com/YOUR-USERNAME/SalesPulse.git
```

Git will use your normal local authentication or browser credential flow. Never paste a personal access token into this project or commit it to the repository.

## Deploy

From this directory:

```bash
sf org login web --alias salespulse-dev --set-default
sf project deploy start --manifest manifest/package.xml --target-org salespulse-dev
```

The `manifest/package.xml` is the source of truth for the deployment set. You can run local static checks before deployment, but Apex tests must be executed in a Salesforce org:

```bash
sf apex run test --target-org salespulse-dev --test-level RunLocalTests --wait 30
```

## Post-deployment setup

1. **Queue membership:** open Setup → Queues → `Sales Inbound` and add the sales representatives who should receive new leads. The app routes to this queue only when the queue exists; if it has been removed, it keeps the current owner.
2. **Named Credential:** open Setup → Named Credentials → `CompanyData`. The included endpoint is deliberately a placeholder (`https://api.example.com`). Replace it with your approved company-data API base URL and adapt the response mapping in `AccountEnrichmentService` to that provider's documented response and authentication scheme. Do not put API keys in Apex or commit them to Git.
3. **Lightning pages:** add `SalesPulse Dashboard` to an App/Home page using Lightning App Builder. Add `Account Enrichment Button` to the Account record page. Assign the relevant page/app to your user.
4. **Permissions:** grant the intended sales users access to the Apex classes and custom fields using a permission set or your org's existing permission model. Review object and field-level access before production use.
5. **Flow:** confirm `Lead Auto Score and Assign` is active. It runs after a new Lead is created.
6. **Validation rules:** the included rules are active. If your sales process permits Leads without phone/email or Closed Won opportunities without an amount, adjust them before deployment to production.

## Lead score model

The example scoring model is intentionally transparent and easy to modify. It awards points for selected industries, company revenue and employee count, presence of email/website, and lead source, then caps the total at 100. Scores map to `Hot` (70+), `Warm` (40–69), and `Cold` (below 40). This is a rule-based baseline, not a trained machine-learning model.

## REST enrichment contract

`AccountEnrichmentService` makes a GET request to:

```text
callout:CompanyData/v1/company?domain=<encoded-domain>
```

It expects a JSON object with optional `description`, `phone`, and `website` string properties. The included `CompanyData` Named Credential uses no authentication and a placeholder URL. Configure a real provider, authentication, limits, terms of use, and an appropriate error-handling policy before using it with customer data.

## Notes and limitations

- The repository contains deployable Salesforce source, not a connected Salesforce org. It has not been deployed into your org from this environment.
- Dashboard totals respect the running user's record visibility (`with sharing`).
- The routing queue has no hard-coded Salesforce IDs; queue lookup uses its stable `DeveloperName`.
- The REST API URL and JSON property mapping must be adapted to the provider you choose.
- For production, review FLS/CRUD enforcement, bulk data volume, API rate limits, queue membership, logging/monitoring, and the validation rules with your Salesforce admin.

## Project layout

```text
force-app/main/default/
  classes/          Apex services, controllers, and tests
  flows/            Record-triggered lead routing Flow
  lwc/              Pipeline dashboard and Account action
  objects/          Custom fields, custom object, validation rules
  queues/           Sales_Inbound queue metadata
  namedCredentials/ CompanyData Named Credential metadata
manifest/package.xml
sfdx-project.json
```

## License

MIT — see `LICENSE`.
