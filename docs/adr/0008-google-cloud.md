# 8. Spry's core on Google Cloud

Status: accepted, 2026-11-18

## Context

Lab 9 asks what it takes to run Spry on another cloud. Spry on AWS (Labs 4-7) is S3 + CloudFront,
Lambda/ECS, Aurora/RDS, Cognito, EventBridge + SQS, SES, Bedrock, all in Terraform (ADR 0007).
Only the frontend, the API and the database move; sign-in, the weekly report and the agenda parser stay on AWS.

## Decision (row by row)

| Spry on AWS | On Google Cloud | Decision |
|---|---|---|
| S3 + CloudFront + WAF | Firebase Hosting | **Replace.** Free plan, CDN and certificate included. A bare Cloud Storage bucket has no HTTPS on a custom domain without a load balancer (hourly bill). `/api/**` is rewritten to Cloud Run: one origin, no CORS. |
| API container (Lambda / ECS) | Cloud Run | **Replace.** The same Docker image; the only change is `--port ${PORT:-8000}`. Min instances 0. The Lambda layer (`awslambdaric`) is used only by the two AWS Lambdas, so it stays in `requirements.txt` for them. |
| ECR | Artifact Registry | **Replace.** 0.5 GB free. |
| Aurora Serverless v2 / RDS | Cloud SQL for PostgreSQL, db-f1-micro, 10 GB SSD | **Replace** (see below). |
| Cognito + Google | Identity Platform | **Keep on AWS** (stretch). The API has no token checks today, so the Cloud Run service is public; this is acceptable only while it serves non-private demo data. |
| EventBridge + SQS (weekly report) | Cloud Scheduler + Pub/Sub | **Keep on AWS.** Works, no gain from moving. |
| SES | none | **Keep SES.** Google has no mail service; multicloud is allowed. If moved: SendGrid, API key in Secret Manager. |
| Bedrock (Claude Haiku) | Vertex AI (Gemini / Claude) | **Keep on AWS.** Prompt `v1` was tuned and evaluated on Claude Haiku (ADR 0006); the trial credit does not pay for partner models on Vertex. |
| SSM / Secrets Manager | Secret Manager | **Replace** for the DB URL only. |
| CloudWatch Logs | Cloud Logging | **Replace** (automatic for Cloud Run). |
| IAM roles | Service accounts | Two: `spry-terraform` (deploys) and `spry-api` (runs the API). No default compute account, no JSON keys. |

### The database

| Option | Latency | Bill (idle month) | Code |
|---|---|---|---|
| Cloud SQL 24/7 | same region as the API, ~1-3 ms | ~$9.40 | none |
| Cloud SQL, stopped when not used | same | ~$1.70 (storage) + $0.0105/h running | none; first request after start waits ~1-2 min |
| Firestore | same region | $0 at student traffic | data layer rewritten: no SQL, no joins, no Alembic |
| Keep Aurora on AWS, call it across clouds | +100-150 ms per query (US to Frankfurt), egress billed, DB exposed to the internet or VPN needed | $0.30 | none, but each page does several queries |

**Chosen: Cloud SQL, db-f1-micro, stopped when not demoed.** Spry is relational (meetings, agenda items),
the SQLAlchemy code and Alembic migrations stay untouched, and ~$9 a month is the price of that.
Firestore is cheaper but is a rewrite, not a move. Cross-cloud calls would put an ocean in every query.
The instance does **not** pause by itself (unlike Aurora): `make gcp-db-stop` / `gcp-db-start`.

Data: migrations (`alembic upgrade head`, run at container start) against the empty database, not pg_dump.
Demo data is re-created by hand; the AWS database is not touched.

### Secrets

Terraform generates the DB password (`random_password`) and writes the whole `DATABASE_URL` to Secret Manager;
Cloud Run reads it as an env var through `spry-api`'s `secretAccessor` role on that one secret. Nothing in Git.
The password is still plaintext in the Terraform state (same caveat as ADR 0007).
E-mail: if SendGrid is used, its API key lives in Secret Manager the same way.

### What would not move, and why

- **Agenda parser:** tuned on Claude; Vertex partner models are not covered by the trial credit.
- **Weekly report:** needs SES and the AWS database; moving it makes the report call across clouds.
- **Sign-in:** works with Cognito; moving it means changing the frontend, the token check and every user account.

### Access for HCP Terraform

Workload Identity Federation: pool `hcp-terraform`, OIDC provider `https://app.terraform.io`, condition on the
numeric organization and workspace IDs, `workloadIdentityUser` on `spry-terraform`. No key exists.
Bootstrap: the first `terraform apply` creates the pool, so it is run once from a laptop with
`gcloud auth application-default login`; after that, HCP uses `TFC_GCP_*` workspace variables.

## Consequences

- Two clouds, two states (`spry-dev` for AWS, `spry-gcp` for GCP): one plan cannot break both.
- The frontend on GCP still talks to Cognito and the parser on AWS; CORS on the parser must allow the Firebase origin.
- Cost rises from ~$0.30 to ~$9.40 a month unless the database is stopped.
