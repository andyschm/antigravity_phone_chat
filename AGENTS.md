# Repository Branching & Integration Workflow (Main-First Strategy)

This project uses a "Main-First" development and extraction workflow. This ensures that you can test all features combined in a single runtime environment while still easily separating and packaging clean, isolated feature branches for upstream PRs.

## Branch Roles

1. **`upstream-master`**
   * **Role:** Tracks the upstream base branch (`origin/master` from `krishnakanthb13/antigravity_phone_chat`) exactly.
   * **Rule:** Never commit directly to this branch. It should only be updated by pulling from the upstream repository.

2. **`main` (Development & Integration Branch)**
   * **Role:** The main branch of your fork. All active development, testing, and combined feature implementation happens directly here.
   * **Rule:** Do not submit PRs directly from `main` to the upstream repository. It is used as the base from which clean feature branches are extracted.

3. **`feat/*` (PR Feature Branches)**
   * **Role:** Pristine, isolated branches containing only the changes relevant to a specific feature/fix for upstream PRs.
   * **Rule:** These branches are created off `upstream-master`. Code is extracted from `main` onto them before they are pushed to your personal fork (`fork`) to open PRs.

---

## Instructions

When working on this repository, you **must** follow these rules:

1. **Developing Features:**
   * Do all your active coding, testing, and debugging on the `main` branch.
   * Verify all features work together in this combined environment.

2. **Packaging a Feature for Upstream PR:**
   * Create a clean branch starting from the latest `upstream-master`:
     ```bash
     git checkout -b feat/your-feature-name upstream-master
     ```
   * Extract only the files/changes belonging to the feature from `main`:
     ```bash
     git checkout main -- path/to/file1 path/to/file2
     ```
     *(If a file contains changes for multiple features, use `git checkout -p main -- path/to/file` or `git add -p` to stage only the relevant lines.)*
   * Commit the changes using Conventional Commits format and push to your fork to open the PR.

---

## Common Maintenance Commands

### 1. Update the tracking branch
```bash
git checkout upstream-master
git pull origin master
```

### 2. Update the main development branch
To bring latest upstream changes into your combined local environment:
```bash
git checkout main
git merge upstream-master --no-edit
```

### 3. Extracting and staging a feature PR branch
```bash
# 1. Update tracking branch
git checkout upstream-master
git pull origin master

# 2. Create clean feature branch
git checkout -b feat/my-new-feature upstream-master

# 3. Extract specific files from main
git checkout main -- public/index.html server.js

# 4. Commit and push
git commit -m "feat(scope): descriptive message"
git push fork feat/my-new-feature
```
