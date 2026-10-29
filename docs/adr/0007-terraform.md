# 7. Terraform instead of CloudFormation

Status: accepted, 2026-10-29

## Context

Auth (Lab 4), the weekly report (Lab 5) and the agenda parser (Lab 6) were three CloudFormation stacks
deployed from a laptop with `make deploy-*`. The project already reaches outside AWS (Google OAuth client,
GitHub) and will need a second environment.

## Decision

- Terraform (`infra/*.tf`), one root module, one HCP Terraform workspace (`spry-dev`), remote execution,
  AWS access through OIDC dynamic credentials (no stored keys).
- Existing resources were adopted with `import` blocks after `DeletionPolicy: Retain` on the stacks,
  not re-created: the user pool holds real accounts and the bucket holds reports.
- Changes go through a pull request: the plan is the check, a merge applies it in HCP Terraform.
  The Makefile has `infra-plan` and no `apply`.
- Terraform ignores `image_uri` of the two image Lambdas. New images go out with `make deploy-reports`
  / `make deploy-ai`, so the app pipeline stays the owner of "which commit runs".

## Alternatives

- **Stay on CloudFormation:** free, AWS keeps the state, but AWS-only and no plan-centred workflow.
- **CDK:** same engine as CloudFormation, plus a build step; no gain for ~40 resources.
- **OpenTofu:** same files and commands, open licence. Terraform was chosen because HCP Terraform
  (state, locking, OIDC runs) is what the course uses; switching later is a rename of the binary.

## Consequences

- Who can change infra: anyone who can open a pull request; only a merge to `main` applies, and only HCP Terraform holds the AWS role.
- Secrets: `google_client_secret` and `database_url` are `sensitive` workspace variables. They are still
  **plaintext in the state** (and in the Lambda environment), so access to the workspace equals access to them.
  Nothing secret is in Git.
- If HCP Terraform is down, nothing is deployed, but nothing running is affected. In an emergency, run
  `terraform apply` from a laptop against the same remote state (locked), then record why in the PR.
- We now own state. Losing it means re-importing every resource; HCP keeps every version of it.
- Drift is visible in every plan: a console fix at 23:00 will be reverted by the next apply unless it is
  copied into the `.tf` files in a pull request.
