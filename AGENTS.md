# Repository Branching & Integration Workflow

This project uses a custom Git workflow designed to keep feature branches clean for upstream PRs while maintaining a combined `main` branch for local development, testing, and deployments.

## Branch Roles

1. **`upstream-master`**
   * **Role:** Tracks the upstream base branch (`origin/master` from `krishnakanthb13/antigravity_phone_chat`) exactly.
   * **Rule:** Never commit directly to this branch. It should only be updated by pulling from the upstream repository.
   
2. **`feat/*` (Feature Branches)**
   * **Role:** Dedicated branches for individual features or fixes (e.g., `feat/oauth2-proxy-auth-bypass`).
   * **Rule:** Always branch off `upstream-master` (`git checkout -b feat/my-feature upstream-master`). Push these branches to your personal fork (`fork`) to create Pull Requests.
   
3. **`main`**
   * **Role:** The integration branch where all active features are combined. This is the default branch of your fork.
   * **Rule:** **Never commit directly to `main`** or use it to generate upstream PRs. It is rebuilt or updated by merging your individual `feat/*` branches.

---

## Instructions

When working on this repository, you **must** follow these branch management rules:

1. **Creating new features:**
   * Always switch to `upstream-master` first.
   * Pull the latest changes from upstream: `git pull origin master`.
   * Create a new branch off `upstream-master`: `git checkout -b feat/your-feature-name upstream-master`.
   * Do all your work and commits in that feature branch.

2. **Integrating features into `main`:**
   * Do not commit your changes directly to `main`.
   * Once a feature is ready or updated, merge it into `main` alongside other active feature branches.

---

## Common Maintenance Commands

### 1. Update the tracking branch
```bash
git checkout upstream-master
git pull origin master
```

### 2. Update and clean a feature branch
```bash
git checkout feat/your-feature
git rebase upstream-master
```

### 3. Rebuild the combined `main` branch (Recommended)
Because feature branches undergo changes and history rewrites, the cleanest way to update `main` is to recreate it from `upstream-master` and merge the active features:
```bash
# Overwrite main with upstream-master
git checkout -B main upstream-master

# Merge all active feature branches
git merge feat/audio-upload-recorder --no-edit
git merge feat/ide-integration-improvements --no-edit
git merge feat/mac-auto-launch-and-qr-fix --no-edit
git merge feat/oauth2-proxy-auth-bypass --no-edit
```
