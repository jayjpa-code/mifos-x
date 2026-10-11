# Mifos X

Unified repository containing the Mifos X core banking deployment foundation for KoreNXT, using Apache Fineract as the backend platform.

## KoreNXT Render deployment

This fork contains a Render Blueprint that provisions:

- Apache Fineract as a Docker web service
- Render PostgreSQL for the Fineract tenant registry and default tenant database
- Fineract runtime environment configuration for Render
- CORS support for Netlify-hosted Mifos Web App environments
- a health check at `/fineract-provider/actuator/health`

[![Deploy to Render](https://render.com/images/deploy-to-render-button.svg)](https://render.com/deploy?repo=https://github.com/jayjpa-code/mifos-x/tree/dev)

Deployment files:

- `render.yaml` — Render infrastructure Blueprint
- `Dockerfile` — pinned Apache Fineract deployment image wrapper
- `render-start.sh` — Render/PostgreSQL runtime adapter

The deployment configuration is validated in GitHub Actions against Render's published Blueprint schema and by building the Docker image.

## Mifos X components

Mifos X is a full core banking platform providing common functionality for creating customers, managing wallets, savings and loan accounts, orchestrating payments, and maintaining the financial ledger and reports.

Upstream components include:

- Back-end platform and APIs — https://github.com/openMF/fineract
- Web User Interface for Staff — https://github.com/openMF/web-app
- Reporting Plug-in — https://github.com/openMF/mifos-reporting-plugin
- Mobile Field Operations App — https://github.com/openMF/android-client
- Customer Mobile Banking App — https://github.com/openMF/mifos-mobile
