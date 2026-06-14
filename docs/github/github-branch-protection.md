# GitHub Repository Configuration

These settings mirror the Rdog repository governance pattern, adapted for
`JohnBetaCode/rtsp_cam_server`.

## 1. Authenticate GitHub CLI

GitHub CLI is installed in this environment. Authenticate before applying remote
settings:

```bash
gh auth login -h github.com
gh auth status
```

## 2. Apply Repository Settings

Run the helper script from the repository root:

```bash
bash scripts/configure_github_repo.sh
```

The script:

- Disables merge commits.
- Keeps squash and rebase merge enabled.
- Enables automatic branch deletion after merge.
- Creates or updates the standard labels used by the templates.
- Protects `main` with the strict rules below.
- Protects `staging` and `develop` only if those branches already exist.

## 3. Branch Protection Rules

### `main` - production / default branch

```bash
gh api repos/JohnBetaCode/rtsp_cam_server/branches/main/protection \
  --method PUT \
  --header "Accept: application/vnd.github+json" \
  --field required_status_checks=null \
  --field enforce_admins=true \
  --field 'required_pull_request_reviews[required_approving_review_count]=1' \
  --field 'required_pull_request_reviews[dismiss_stale_reviews]=true' \
  --field 'required_pull_request_reviews[require_code_owner_reviews]=false' \
  --field restrictions=null \
  --field allow_force_pushes=false \
  --field allow_deletions=false \
  --field required_linear_history=true
```

### `staging` - integration branch, if added later

```bash
gh api repos/JohnBetaCode/rtsp_cam_server/branches/staging/protection \
  --method PUT \
  --header "Accept: application/vnd.github+json" \
  --field required_status_checks=null \
  --field enforce_admins=false \
  --field 'required_pull_request_reviews[required_approving_review_count]=1' \
  --field 'required_pull_request_reviews[dismiss_stale_reviews]=true' \
  --field 'required_pull_request_reviews[require_code_owner_reviews]=false' \
  --field restrictions=null \
  --field allow_force_pushes=false \
  --field allow_deletions=false \
  --field required_linear_history=false
```

### `develop` - active development branch, if added later

```bash
gh api repos/JohnBetaCode/rtsp_cam_server/branches/develop/protection \
  --method PUT \
  --header "Accept: application/vnd.github+json" \
  --field required_status_checks=null \
  --field enforce_admins=false \
  --field required_pull_request_reviews=null \
  --field restrictions=null \
  --field allow_force_pushes=false \
  --field allow_deletions=false \
  --field required_linear_history=false
```

### Branch Protection Summary

| Rule | `main` | `staging` | `develop` |
|---|:---:|:---:|:---:|
| Require PR | yes | yes | no |
| Approvals required | 1 | 1 | - |
| Dismiss stale reviews | yes | yes | - |
| Enforce on admins | yes | no | no |
| Require linear history | yes | no | no |
| Block force pushes | yes | yes | yes |
| Prevent branch deletion | yes | yes | yes |

### Adding CI Status Checks

Once GitHub Actions jobs exist, replace `required_status_checks=null` with:

```bash
--field 'required_status_checks[strict]=true' \
--field 'required_status_checks[contexts][]=<job-name>'
```

Use the exact GitHub Actions job name for `<job-name>`.

## 4. Repository Merge Settings

```bash
gh api repos/JohnBetaCode/rtsp_cam_server \
  --method PATCH \
  --header "Accept: application/vnd.github+json" \
  --field delete_branch_on_merge=true \
  --field allow_merge_commit=false \
  --field allow_squash_merge=true \
  --field allow_rebase_merge=true
```

| Setting | Value |
|---|---|
| Auto-delete head branches | enabled |
| Allow merge commits | disabled |
| Allow squash merge | enabled |
| Allow rebase merge | enabled |

## 5. Issue And PR Templates

Templates live in `.github/` and are committed to the repo:

```text
.github/
├── ISSUE_TEMPLATE/
│   ├── bug_report.yml
│   ├── feature_request.yml
│   └── hotfix.yml
└── pull_request_template.md
```

## 6. Labels

| Group | Labels |
|---|---|
| Type | `type_bug` `type_feature` `type_enhancement` `type_hotfix` `type_release` `type_chore` `type_docs` |
| Priority | `PRIORITY_LOW` `PRIORITY_MEDIUM` `PRIORITY_HIGH` `PRIORITY_SATANIC` |
| State | `state_in_progress` `state_tech_check` `state_qa_check` `state_ready_to_test` `state_testing` |
| System | `sys_streaming` `sys_api` `sys_config` `sys_docs` `sys_cicd` `sys_other` |
| Automation | `automerge` `automergesquash` `auto_generated` `hold_on` |
