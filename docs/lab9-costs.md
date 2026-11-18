# Lab 9: cost of Spry's core (USD per month, list prices, us-east-1 vs us-central1)

Assumptions: Lambda/Cloud Run and CloudFront/Firebase stay within free tiers at this traffic (2M requests,
10 GB hosting); Aurora at 0.5 ACU minimum while awake, $0.12 per ACU-hour; ~1 GB database (AWS $0.10/GB),
10 GB SSD on Cloud SQL ($0.17/GB, billed while stopped); Cloud SQL db-f1-micro $0.0105/h; 730 h/month.
The idle-month AWS total (~$0.30) matches the Lab 9 reference table; the other AWS figures are recomputed from the prices above.

## Idle month (reference)

| Piece | AWS | Google Cloud (Cloud SQL) |
|---|---|---|
| Frontend + CDN + HTTPS | $0 | $0 |
| API | $0 | $0 |
| DB compute | $0 (paused) | $7.67 |
| DB storage | $0.10 | $1.70 |
| Registry, secrets, logs | ~$0.20 | $0 (free tier) |
| **Total** | **~$0.30** | **~$9.40** (~$1.70 stopped) |

## Four traffic profiles

| Profile | DB awake | AWS Aurora | GCP Cloud SQL always on | GCP Cloud SQL stopped when idle | GCP Firestore |
|---|---|---|---|---|---|
| Nobody | 0 h | $0.30 | $9.37 | $1.70 | $0 |
| Class demos (10 x 2 h) | 20 h | $0.30 + 20 x 0.5 x 0.12 = **$1.50** | $9.37 | $1.70 + 0.21 = **$1.91** | $0 |
| Office hours (8 h x 22 d) | 176 h | $0.30 + 10.56 = **$10.86** | $9.37 | $1.70 + 1.85 = **$3.55** | $0 |
| Busy around the clock | 730 h | $0.30 + 43.80 = **$44.10** | $9.37 | $9.37 | $0 (if < 50k reads/day) |

## Answers

- **Cheapest:** nobody and class demos: AWS (pauses, so compute is $0) or Firestore ($0). Office hours: Cloud SQL
  (flat $9.37) is about the same as Aurora ($10.86). Around the clock: Cloud SQL $9.37 beats Aurora $44.10 by a wide margin.
  The deciding line is **database compute**: pay-per-use (Aurora ACU-hours) against a flat shared-core instance.
- **The GCP trap:** Cloud SQL never pauses, so a forgotten instance bills $7.67 a month at zero traffic, and the
  10 GB disk bills even when stopped ($1.70). The mirror of the
  Aurora trap (a health check keeping it awake): here the trap is *forgetting* it. Firestore's trap is the other kind:
  a list page reading 500 documents per visit exhausts 50,000 free reads a day after 100 visits.

## Part 4 evidence (project spry-danylokoval-2026)

- **BigQuery:** `docs/lab9/bigquery.jpg`, top Texas names from `bigquery-public-data.usa_names.usa_1910_2013`; 105.24 MB processed, well inside the 1 TiB monthly free tier.
- **Looker Studio:** `docs/lab9/looker-studio.jpg`, line chart over `spry_lab9.names_by_year` (a table saved from the BigQuery query).
- **Vision API OCR:** `docs/lab9/vision-ocr.jpg` and `vision-ocr.txt`, TEXT_DETECTION on a screenshot of the deployed Spry frontend (1 call, free tier is 1,000 units).
- **Spry on GCP:** `docs/lab9/spry-on-gcp.jpg`, https://spry-danylokoval-2026.web.app listing a meeting read from Cloud SQL through Firebase's `/api/**` rewrite to Cloud Run.
- Budget alert: $5 a month, 50/90/100% (spry-lab9-5usd). Cloud SQL was stopped after the screenshots.
