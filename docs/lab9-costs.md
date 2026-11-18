# Lab 9: cost of Spry's core (USD per month, list prices, us-east-1 vs us-central1)

Assumptions: Lambda/Cloud Run and CloudFront/Firebase stay within free tiers at this traffic (2M requests,
10 GB hosting); Aurora at 0.5 ACU minimum while awake, $0.12 per ACU-hour; ~1 GB database (AWS $0.10/GB),
10 GB SSD on Cloud SQL ($0.17/GB, billed while stopped); Cloud SQL db-f1-micro $0.0105/h; 730 h/month.
Lab 4 AWS figures were not in this repo, so the AWS column is recomputed from the prices above: check it against Lab 4.

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
