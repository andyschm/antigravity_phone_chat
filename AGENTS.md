# Repository Branching & Integration Workflow (Main-First Strategy)

> [!IMPORTANT]
> **CRITICAL RULE FOR AI AGENTS:**
> ALWAYS check the current branch before starting development. All active coding, testing, and debugging **MUST** be performed directly on the `main` branch. 
> Do **NOT** implement new features or bug fixes directly on a feature branch (`feat/*`) or a tracking branch (`upstream-master`). If you find yourself on a branch other than `main` at start, stash your changes and switch to `main` before starting development.

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

2. **Packaging a Feature for Upstream PR (Without Disrupting the Server):**
   To avoid breaking the running server or triggering unnecessary file reload watches in the active development workspace, use `git worktree` to package feature branches inside the `worktrees/` directory (which is gitignored):
   ```bash
   # 1. Update the local upstream-master from origin (run from main workspace)
   git fetch origin master:upstream-master

   # 2. Add a temporary worktree linked to the new feature branch
   git worktree add -b feat/your-feature-name worktrees/temp-feature-branch upstream-master

   # 3. Switch to the temporary worktree directory
   cd worktrees/temp-feature-branch

   # 4. Extract only the files/changes belonging to the feature from main
   git checkout main -- path/to/file1 path/to/file2
   # (If a file contains changes for multiple features, use git checkout -p main -- path/to/file or git add -p)

   # 5. Commit and push the clean feature branch
   git commit -m "feat(scope): descriptive message"
   git push fork feat/your-feature-name

   # 6. Return to the active workspace and clean up the temporary worktree
   cd -
   git worktree remove worktrees/temp-feature-branch
   ```

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

### 3. Extracting and staging a feature PR branch (via worktree)
```bash
# 1. Update tracking branch
git fetch origin master:upstream-master

# 2. Create clean feature branch in a temporary worktree
git worktree add -b feat/my-new-feature worktrees/temp-feature-branch upstream-master

# 3. Switch to the worktree directory
cd worktrees/temp-feature-branch

# 4. Extract specific files from main
git checkout main -- public/index.html server.js

# 5. Commit and push
git commit -m "feat(scope): descriptive message"
git push fork feat/my-new-feature

# 6. Clean up
cd -
git worktree remove worktrees/temp-feature-branch
```
