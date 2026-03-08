# GitHub Teams Setup Guide

This guide covers the manual GitHub configuration steps required to use the team deployment workflows. All workflow files are already included — you just need to configure the GitHub settings below.

---

## Prerequisites

- A **GitHub Team plan** (or higher) for your organization
- Admin access to the repository settings

---

## Step 1: Create Environments

Go to **Settings → Environments** and create three environments:

### `staging`
- No protection rules needed (auto-deploys on every push to `master`)

### `production`
1. Click **"Add protection rule"**
2. Enable **"Required reviewers"** and add 1–2 team leads
3. Optionally set a **wait timer** (e.g. 5 minutes) to allow time for smoke-testing the staging build
4. Under **"Deployment branches"**, select **"Selected branches"** and add `master`

### `pr-preview`
- No protection rules needed

---

## Step 2: Set GitHub Pages to Private (Team Plan Feature)

1. Go to **Settings → Pages**
2. Under **"Access"**, change from **"Public"** to **"Private"**
3. Only authenticated organization members with repository access will be able to view the deployed site

> This is a GitHub Team plan exclusive feature. On the Free plan, Pages are always public.

---

## Step 3: Configure Branch Protection Rules

Go to **Settings → Branches → Add branch protection rule** for the `master` branch:

| Setting | Value |
|---------|-------|
| **Branch name pattern** | `master` |
| **Require a pull request before merging** | Enabled |
| **Required approving reviews** | 1 (or more) |
| **Require review from Code Owners** | Enabled (uses existing `.github/CODEOWNERS`) |
| **Require status checks to pass before merging** | Enabled |
| **Required status checks** | `Validate changed demos export successfully` |
| **Require branches to be up to date before merging** | Enabled |

---

## Step 4: Configure Actions Permissions

Go to **Settings → Actions → General**:

1. Under **"Workflow permissions"**, select **"Read and write permissions"**
   - This allows the PR preview workflow to post comments on pull requests
2. Enable **"Allow GitHub Actions to create and approve pull requests"** (optional)

---

## What Each Workflow Does

### `export_web.yml` — Staging → Production Pipeline
- **Trigger:** Push to `master`
- **Flow:**
  1. `export-html5`: Exports all demos to HTML5/WASM (uploads as artifact)
  2. `deploy-staging`: Auto-deploys to `gh-pages-staging` branch
  3. `deploy-production`: Waits for manual approval (production environment), then deploys to `gh-pages`
- **Team feature used:** Environment protection rules on `production`

### `pr_preview.yml` — PR Preview Builds
- **Trigger:** Pull request to `master` that modifies demo files
- **Flow:**
  1. Detects which demo directories changed in the PR
  2. Exports only those demos (fast — usually 2–5 minutes)
  3. Uploads the exported files as a downloadable artifact
  4. Posts a comment on the PR with a link to the artifact
- **Team feature used:** `pr-preview` environment for deployment tracking

### `validate_demos.yml` — Export Validation Check
- **Trigger:** Pull request to `master` that modifies demo files
- **Flow:**
  1. Detects changed demos
  2. Attempts to export each one
  3. Reports pass/fail for each demo
  4. Fails the check if any export fails — blocks the PR from merging
- **Team feature used:** Required status check in branch protection

### `promote_to_production.yml` — Manual Promotion
- **Trigger:** Manual dispatch (Actions → "Promote Staging to Production" → Run workflow)
- **Flow:**
  1. Requires typing "promote" as confirmation
  2. Copies the `gh-pages-staging` branch content to `gh-pages`
  3. Requires production environment approval
- **Team feature used:** `workflow_dispatch` + environment protection

---

## How the Team Workflow Looks in Practice

```
Developer pushes to feature branch
    │
    ▼
Opens Pull Request → master
    │
    ├── ✅ static_checks (formatting)
    ├── ✅ check_urls (broken links)
    ├── ✅ validate_demos (export test)    ← blocks merge if broken
    ├── 📦 pr_preview (artifact + PR comment)
    └── 👀 CODEOWNERS review required
    │
    ▼
PR merged to master
    │
    ▼
export_web.yml runs:
    ├── 1. Export all demos (15–30 min)
    ├── 2. Deploy to staging (automatic)
    └── 3. Deploy to production (requires approval)
              │
              ▼
         Team lead reviews staging site
              │
              ▼
         Approves in GitHub UI → Production deployed
```

---

## Viewing Deployments

- **Deployment history:** Go to the repository home page → right sidebar → **"Environments"**
- Each environment shows its deployment history, status, and approval records
- Click on any deployment to see logs and the deployed URL

---

## Troubleshooting

### "Required status check not found" when setting up branch protection
The `validate_demos` check won't appear in the dropdown until it has run at least once. Create a test PR that modifies any demo file to trigger it, then configure the branch protection rule.

### PR preview comment doesn't appear
Check **Settings → Actions → General** and ensure "Read and write permissions" is enabled for the `GITHUB_TOKEN`.

### Production deploy is auto-approved (no gate)
Verify the `production` environment has "Required reviewers" configured in **Settings → Environments → production**.
