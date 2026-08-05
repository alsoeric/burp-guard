# Jujutsu (jj) Version Control Workflow Guide

A complete, step-by-step practical reference for managing code repositories with **Jujutsu (`jj`)**—from initializing an empty directory to linking a remote Git server, managing changes, and pushing bookmarks.

---

## 1. Quick Command Cheat Sheet

| Task | Jujutsu (`jj`) Command | Notes |
| :--- | :--- | :--- |
| **Initialize Repo** | `jj git init` | Initialized in existing directory |
| **Check Status** | `jj status` | Views changed/untracked files |
| **View Log Graph** | `jj log` | Shows commit tree and `@` working copy |
| **Review Changes** | `jj diff` | Inspects line-by-line diffs |
| **Describe Change** | `jj describe -m "msg"` | Attaches commit message to current change |
| **New Clean Slate** | `jj new` | Closes active change, starts fresh working copy |
| **Set Remote URL** | `jj git remote add origin <URL>` | Connects new remote endpoint |
| **Update Remote URL**| `jj git remote set-url origin <URL>` | Updates existing remote address |
| **Set Bookmark** | `jj bookmark set main -r @-` | Moves bookmark pointer to described commit |
| **Push Bookmark** | `jj git push --remote origin --bookmark main` | Pushes local bookmark to remote |
| **Push New Bookmark**| `jj git push --remote origin --bookmark main --allow-new` | First push of a brand-new remote bookmark |
| **Fetch Remote** | `jj git fetch --remote origin` | Synchronizes remote tracking pointers |

---

## 2. Fundamental Concepts & Terminology

Before running commands, it helps to understand how Jujutsu differs from traditional Git:

1. **No `git add` is Ever Needed:**
   `jj` automatically tracks all untracked files and modifications in real time within your current working change (`@`). You never need to stage files using `git add`.

2. **`jj describe` vs. `git commit`:**
   * **In Git:** Running `git commit` creates a permanent snapshot, closes the current commit, and moves your branch pointer forward. To add a message, you must commit.
   * **In `jj`:** Running `jj describe` does **not** close a commit or create a new revision in history. It simply updates or renames the text message on your *current active change* (`@`). You can run `jj describe` multiple times on the same change to refine its message without creating extra commits.

3. **Multiple `jj describe`s Before `jj new` (Example):**
   If you make edits and run `jj describe` multiple times *without* running `jj new`, you are just overwriting the commit message on that single change:

   ```bash
   # 1. Edit code
   jj describe -m "WIP: working on bashrc"    # Message set to "WIP: working on bashrc"
   
   # 2. Make more edits to the SAME change
   jj describe -m "feat: complete bashrc script" # Overwrites previous message
   ```

   **What `jj log` looks like:**
   ```text
   @  pkkzsutv user@domain 2026-08-05 16:00:00 20bb42f8
   │  feat: complete bashrc script
   ◆  zzzzzzzz root() 00000000
   ```
   *Result:* Only **one** commit exists in history. The second `jj describe` simply replaced the text of the first.

4. **`jj new` is What Creates Separate Commits:**
   To turn your work into multiple distinct commits in history, you must use `jj new` to finalize the current change and open a new one:

   ```bash
   # First Commit
   vim .bashrc
   jj describe -m "feat: configure bashrc"
   jj new                                      # Closes change 1, opens change 2 (@)

   # Second Commit
   vim .bash_profile
   jj describe -m "feat: configure bash_profile"
   ```

   **What `jj log` looks like now:**
   ```text
   @  a1b2c3d4 user@domain 2026-08-05 16:05:00 99xx88yy
   │  (empty) feat: configure bash_profile
   ○  pkkzsutv user@domain 2026-08-05 16:00:00 20bb42f8
   │  feat: configure bashrc
   ◆  zzzzzzzz root() 00000000
   ```

5. **Bookmarks Replace Branches:**
   In `jj` version 0.31+, branch markers (like `main` or `master`) are explicitly called **bookmarks**.

---

## 3. Workflow Flowchart

```text
[ Empty Project Directory ]
           │
           ▼
     jj git init                  <── Initialize Jujutsu repo with Git backend
           │
           ▼
[ Edit files / add scripts ]
           │
           ▼
     jj status & jj diff          <── Inspect active changes (captured automatically)
           │
           ▼
  jj describe -m "description"   <── Add commit message to current change
           │
           ▼
        jj new                    <── Close change and open fresh working copy (@)
           │
           ▼
  jj bookmark set main -r @-      <── Point local 'main' bookmark to described parent (@-)
           │
           ▼
jj git remote add origin <URL>    <── Link remote Git repository (SSH / HTTPS)
           │
           ▼
jj git push --remote origin    --bookmark main --allow-new    <── Push bookmark & commits to remote
```

---

## 4. End-to-End Walkthrough

### Step 1: Initialize a New Jujutsu Repository

Navigate to your target directory (or create a new one) and initialize Jujutsu with a Git storage backend:

```bash
mkdir -p ~/Projects/my-app
cd ~/Projects/my-app

# Initialize Jujutsu with Git backend capability
jj git init
```

---

### Step 2: Make Changes & Manage the Working Copy

Create your project files as normal. `jj` automatically tracks file additions and updates in the working change (`@`).

```bash
# Create files
echo "# My App" > README.md
echo "echo 'Hello World'" > app.sh
chmod +x app.sh

# Check tracked changes
jj status

# Review exact line diffs
jj diff
```

---

### Step 3: Describe and Complete the Change

Assign a commit message to your change, then open a clean slate for subsequent work:

```bash
# 1. Label/describe the current working change (@)
jj describe -m "feat: initial project structure and entry script"

# 2. Complete the change and open a new empty working copy (@)
jj new
```

To view your newly committed change in the revision graph:

```bash
jj log
```

**Example Log Output:**
```text
@  pkkzsutv user@domain 2026-08-05 16:00:00 20bb42f8
│  (empty) (no description set)
○  ousyuzlm user@domain 2026-08-05 15:58:00 ef4d4523
│  feat: initial project structure and entry script
◆  zzzzzzzz root() 00000000
```

---

### Step 4: Link to a Remote Git Repository

Add your remote repository endpoint. Choose SSH (preferred) or HTTPS depending on your infrastructure setup.

#### Option A: Adding a New Remote (`jj git remote add`)
Use `add` when configuring a remote for the first time in this local repository:

```bash
# SSH Remote (using host alias or explicit address)
jj git remote add origin giteaserver:username/my-app.git

# Or standard SSH URL:
# jj git remote add origin git@github.com:username/my-app.git
```

#### Option B: Modifying an Existing Remote (`jj git remote set-url`)
If `origin` already exists (e.g., previously set to an HTTPS URL or expired certificate domain) and needs updating:

```bash
jj git remote set-url origin giteaserver:username/my-app.git
```

---

### Step 5: Assign the Bookmark Pointer

Set your local bookmark marker (`main`) to point at your completed parent revision (`@-`):

```bash
jj bookmark set main -r @-
```

> **Syntax Tip:**
> * `@` refers to your current empty working copy.
> * `@-` refers to the parent commit directly beneath your current working copy (the change described in Step 3).

---

### Step 6: Push to the Remote Repository

#### First Push (Creating Remote Bookmark)
Because the `main` bookmark does not exist on the remote server yet, include `--allow-new`:

```bash
jj git push --remote origin --bookmark main --allow-new
```

#### Subsequent Pushes
For ongoing updates after the remote bookmark has been initialized:

```bash
jj git push --remote origin --bookmark main
```

---

### Step 7: Verification

Verify that your local bookmark and remote tracking bookmark match:

```bash
jj log -r "main | main@origin"
```

**Expected Output:** Both `main` and `main@origin` sit on the exact same commit hash:
```text
○  ousyuzlm user@domain 2026-08-05 15:58:00 main main@origin | feat: initial project structure...
```

---

## 5. Daily Iteration Loop

For day-to-day ongoing development, follow this standard cycle:

```bash
# 1. Edit code / add features
vim app.sh

# 2. Inspect status and diffs
jj status
jj diff

# 3. Describe your change
jj describe -m "fix: sanitize user inputs in app.sh"

# 4. Move local bookmark to completed change
jj bookmark set main -r @

# 5. Push to remote
jj git push --remote origin --bookmark main

# 6. Open a clean slate for the next task
jj new
```


---

## 6. Common Errors & Troubleshooting

### Error: "Won't push commit ... since it has no description"

#### Cause:
`jj` prevents pushing commits to a remote if any commit in the push chain is empty and lacks a description (e.g., an abandoned empty working copy left in history).

#### Example Error Output:
```text
Error: Won't push commit b882ced106f1 since it has no description
Hint: Rejected commit: pkkzsutv b882ced1 (empty) (no description set)
```

#### Solution Options:

* **Option A: Abandon the Empty Commit (Recommended)**
  If the empty commit was created accidentally or is no longer needed, abandon it. `jj` will automatically rebase and stitch your subsequent work onto its parent:
  ```bash
  jj abandon <commit-id-or-change-id>
  ```

* **Option B: Describe the Commit**
  If you want to keep the commit, give it a description before pushing:
  ```bash
  jj describe -r <commit-id-or-change-id> -m "chore: commit description"
  ```

---

## 7. The Two Valid Bookmark & Push Patterns

To ensure you never accidentally include an empty active working copy (`@`) in a push, use one of these two standard workflows:

### Pattern A: `jj new` First (Recommended)
Close off your change into a parent commit (`@-`), set the bookmark to the parent, then push:

```bash
# 1. Label active change
jj describe -m "feat: my changes"

# 2. Open a new clean working copy (@)
jj new

# 3. Move bookmark to parent change (@-)
jj bookmark set main -r @-

# 4. Push bookmark
jj git push --remote origin --bookmark main
```

---

### Pattern B: Set Bookmark First, Then `jj new`
Attach the bookmark directly to your active change (`@`), open a new working copy, then push:

```bash
# 1. Label active change
jj describe -m "feat: my changes"

# 2. Set bookmark to active change (@)
jj bookmark set main -r @

# 3. Open a new clean working copy (@) above main
jj new

# 4. Push bookmark
jj git push --remote origin --bookmark main
```
