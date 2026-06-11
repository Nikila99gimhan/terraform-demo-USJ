# Terraform on AWS — Demo Repository

A hands-on demo for learning Terraform state management and GitHub Actions automation on AWS.

---

## What's Inside

```
.
├── .github/workflows/
│   ├── terraform-plan-apply.yml   # Run plan or apply
│   ├── terraform-destroy.yml      # Destroy resources
│   └── _reusable-terraform.yml    # Shared workflow logic
│
└── terraform-demo/
    ├── 01-bootstrap/main.tf       # Creates S3 bucket for remote state (local state)
    └── 02-infrastructure/main.tf  # Deploys VPC + EC2 (remote state in S3)
```

---

## GitHub Actions Workflows

### How it works

- **`_reusable-terraform.yml`** — the core logic. Handles init, plan, apply, destroy. Not triggered directly.
- **`terraform-plan-apply.yml`** — calls the reusable workflow. You pick the action and the module.
- **`terraform-destroy.yml`** — calls the reusable workflow with destroy action. You pick the module.

### Why reusable workflows?

- Write the Terraform logic once, use it from both workflows
- Consistent behaviour — no duplicated steps
- Easy to update: change `_reusable-terraform.yml` and both workflows get the fix automatically

### Running a workflow

Go to **Actions → select workflow → Run workflow**, then pick:

| Input | Options |
|---|---|
| Action | `plan` or `apply` |
| Module | `bootstrap` or `infrastructure` |

> Always run `bootstrap` before `infrastructure`. Always destroy `infrastructure` before `bootstrap`.

---

## AWS ↔ GitHub Actions Connection

### Why OIDC (and not just using access keys)?

| Method | How it works | Risk |
|---|---|---|
| **Access Keys** | Long-lived key + secret stored as GitHub secret | If leaked, attacker has permanent access |
| **OIDC (this repo)** | GitHub gets a short-lived token per job, exchanges it for temporary AWS credentials | No long-lived secret. Token expires after the job. |

OIDC is the AWS and GitHub recommended approach. No secret rotation needed, no leaked credentials risk.

### How the trust is locked down

The IAM role's trust policy is scoped to this exact repo:

```json
"token.actions.githubusercontent.com:sub": "repo:Nikila99gimhan/terraform-demo-USJ:*"
```

Only this repo's workflows can assume the role — no other GitHub repo can.

---

## Fork & Run It Yourself

### Step 1 — Fork this repo

Click **Fork** on GitHub. All the workflow files come with it.

### Step 2 — Set up AWS OIDC

**In AWS Console:**

1. **IAM → Identity Providers → Add Provider**
   - Type: OpenID Connect
   - URL: `https://token.actions.githubusercontent.com`
   - Audience: `sts.amazonaws.com`

2. **IAM → Roles → Create Role**
   - Trusted entity: Web Identity → select the provider above
   - Attach policies: `AmazonS3FullAccess`, `AmazonEC2FullAccess`, `AmazonVPCFullAccess`
   - Name it: `github-actions-terraform`

3. **Edit the Trust Policy** of the role — update the `sub` condition to your forked repo:
   ```
   repo:YOUR_GITHUB_USERNAME/YOUR_REPO_NAME:*
   ```

4. Copy the **Role ARN** — looks like:
   ```
   arn:aws:iam::YOUR_ACCOUNT_ID:role/github-actions-terraform
   ```

### Step 3 — Add the secret to your fork

Go to your forked repo → **Settings → Secrets and variables → Actions → New repository secret**

| Name | Value |
|---|---|
| `AWS_ROLE_ARN` | `arn:aws:iam::YOUR_ACCOUNT_ID:role/github-actions-terraform` |

### Step 4 — Update the S3 backend

Run Phase 1 (bootstrap) locally first:

```bash
cd terraform-demo/01-bootstrap
terraform init && terraform apply
```

Then update `terraform-demo/02-infrastructure/main.tf` with your bucket name:

```hcl
backend "s3" {
  bucket       = "terraform-state-YOUR_ACCOUNT_ID-demo"
  ...
}
```

Commit and push — then trigger the workflows from GitHub Actions.

---

## Security Note for Public Repos

- **Secrets are safe** — GitHub never exposes secrets in logs or to forks
- **OIDC trust is repo-scoped** — only your repo can assume the AWS role
- **Workflow triggers are owner-controlled** — only repo collaborators can trigger `workflow_dispatch`
- **Account ID in code is low risk** — AWS account IDs are not secret by nature

---

*Built for the USJ Session · Terraform + GitHub Actions · Infrastructure as Code*
