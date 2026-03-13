---
name: deploy-to-edgeone
description: Deploy applications and websites to EdgeOne Pages. Use when the user requests deployment actions like "deploy my app", "deploy to EdgeOne", "push this live", or "create a preview deployment".
metadata:
  author: edgeone-pages
  version: "1.0.0"
---

# Deploy to EdgeOne Pages

Deploy any project to EdgeOne Pages. **Always deploy as preview** (not production) unless the user explicitly asks for production.

The goal is to get the user into the best long-term setup: their project linked to EdgeOne Pages with easy CLI deploys. Every method below tries to move the user closer to that state.

## Step 1: Gather Project State

Run all checks before deciding which method to use:

```bash
# 1. Check if EdgeOne CLI is installed
command -v edgeone 2>/dev/null && edgeone -v

# 2. Check if authenticated
edgeone whoami 2>/dev/null

# 3. Check for a git remote
git remote get-url origin 2>/dev/null

# 4. Check if project has a build output directory (common ones)
ls -d dist build out .next .output public 2>/dev/null

# 5. Check if package.json exists and has a build script
cat package.json 2>/dev/null | grep -A1 '"build"'
```

## Step 2: Choose a Deploy Method

Based on the checks above, follow the appropriate path:

---

### Path A: CLI installed + authenticated → Deploy directly

This is the ideal state. The CLI is ready to go.

**Preview deployment (default):**

```bash
edgeone pages deploy [path] -e preview
```

**Production deployment (only if user explicitly asks):**

```bash
edgeone pages deploy [path]
```

> **Note:** EdgeOne Pages defaults to `production` environment. Always pass `-e preview` unless the user explicitly wants production.

**With a project name (to target a specific project):**

```bash
edgeone pages deploy [path] -n <project-name> -e preview
```

If the project hasn't been deployed to EdgeOne Pages before, the CLI will automatically create a new project.

---

### Path B: CLI installed + NOT authenticated → Login first, then deploy

The CLI is installed but the user hasn't logged in.

1. **Offer two authentication options:**

```
EdgeOne CLI is installed but not authenticated. You have two options:

1. **Browser login** (recommended for local development):
   Run `edgeone login` — a browser window will open for authentication.

2. **API Token** (recommended for CI/CD or if browser login is not available):
   - Go to EdgeOne Pages console to generate an API Token
   - Then deploy with: `edgeone pages deploy -n <project-name> -t <your-api-token>`

Which method would you prefer?
```

2. **If user chooses browser login:**

```bash
edgeone login
```

Wait for the user to complete authentication in the browser. After successful login, verify:

```bash
edgeone whoami
```

Then proceed to **Path A** for deployment.

3. **If user chooses API Token:**

The user provides their token, then deploy directly:

```bash
edgeone pages deploy [path] -n <project-name> -t <api-token> -e preview
```

---

### Path C: CLI NOT installed → Install, authenticate, then deploy

The EdgeOne CLI is not installed at all.

1. **Install the CLI:**

```bash
npm install -g edgeone
```

Verify installation:

```bash
edgeone -v
```

2. **Authenticate** — follow the same flow as Path B (offer browser login or API Token).

3. **Deploy** — follow the same flow as Path A.

---

### Path D: API Token deployment (non-interactive / CI/CD)

For environments where browser login is not possible (CI/CD pipelines, sandboxed environments), use the API Token directly:

```bash
edgeone pages deploy [path] -n <project-name> -t <api-token> -e preview
```

**Tell the user** how to get an API Token:

```
To get an API Token:
1. Go to EdgeOne Pages console (https://console.cloud.tencent.com/edgeone/pages)
2. Navigate to your account settings
3. Generate a new API Token
4. Use it with the -t flag for deployment
```

---

## Step 3: Build Before Deploy (IMPORTANT — always prefer local build)

**⚠️ CRITICAL: Always try to build locally first, then deploy the build output directory.** EdgeOne Pages remote build may encounter network timeout issues (e.g., `ConnectTimeoutError` when fetching dependencies). Local build avoids this entirely.

### Recommended flow:

1. **Check if build output already exists:**

```bash
ls -d dist build out .next .output 2>/dev/null
```

2. **If no build output, build locally:**

```bash
npm install
npm run build
```

3. **Deploy the build output directory (NOT the project root):**

```bash
# For Vite / Vue CLI / Rollup projects:
edgeone pages deploy ./dist -n <project-name> -e preview

# For Create React App:
edgeone pages deploy ./build -n <project-name> -e preview

# For Next.js:
edgeone pages deploy .next -n <project-name> -e preview

# For Next.js static export:
edgeone pages deploy ./out -n <project-name> -e preview

# For Nuxt 3:
edgeone pages deploy .output -n <project-name> -e preview
```

4. **Common build output directories:**
   - `dist/` — Vite, Vue CLI, Rollup
   - `build/` — Create React App
   - `out/` — Next.js static export
   - `.next/` — Next.js
   - `.output/` — Nuxt 3
   - `public/` — Some static site generators

5. **Only use auto-build as fallback** (when local build is not possible):

```bash
edgeone pages deploy -n <project-name> -e preview
```

Without specifying a path, the CLI will attempt to build remotely and deploy — but this may fail due to network timeouts.

### Why local build first?

The EdgeOne Pages remote build environment may have network connectivity issues when installing dependencies (e.g., `mirrors.tencent.com` timeout). Building locally ensures:
- Dependencies are resolved using your local network
- Build errors are caught immediately
- Only the final build artifacts are uploaded, which is faster

---

## Step 4: Link Project (optional but recommended)

After the first deployment, recommend the user to link their project for easier management:

```bash
edgeone pages link
```

This links the local project to the EdgeOne Pages project, enabling:
- Environment variable sync (`edgeone pages env pull`)
- Easier subsequent deploys
- KV storage access

---

## Output

Always show the user the deployment URL after a successful deploy.

**Example output format:**

```
🎉 Deployment successful!

| Item         | Details                                              |
|--------------|------------------------------------------------------|
| **Status**   | ✅ Ready                                              |
| **URL**      | https://<project-name>.edgeone.app                   |
| **Env**      | Preview / Production                                 |
| **Project**  | <project-name>                                       |

You can visit the URL above to see your deployed site.
```

**Do not** curl or fetch the deployed URL to verify it works. Just return the link.

---

## Environment Variables

If the user needs to manage environment variables:

```bash
# List all environment variables
edgeone pages env ls

# Pull environment variables to local .env file
edgeone pages env pull

# Add a new environment variable
edgeone pages env add <KEY> <VALUE>

# Remove an environment variable
edgeone pages env rm <KEY>
```

---

## Troubleshooting

### Project Limit Exceeded (Pages project exceeds 40 limit) — IMPORTANT

If deployment fails with error `Pages project exceeds 40 limit`, the user's account has reached the maximum number of projects (40). **You MUST handle this proactively.**

**Tell the user:**

```
⚠️ Your EdgeOne Pages account has reached the project limit (40 projects).
You need to delete some existing projects before creating a new one.

You have two options:

**Option 1: Delete via Console (recommended)**
Go to the EdgeOne Pages console to manage and delete projects:
👉 https://edgeone.ai/pages

**Option 2: Delete via API (I can help)**
Provide me with:
1. Your API Token (generate one from the EdgeOne Pages console)
2. The Project ID(s) you want to delete (format: pages-xxxxx)

I'll call the API to delete them for you.
```

**If the user chooses Option 2 (API deletion):**

The user needs to provide their `api_token` and the `project_id` to delete. Then execute the following curl command:

```bash
curl -X POST 'https://pages-api.cloud.tencent.com/v1' \
  -H 'Content-Type: application/json' \
  -H 'Authorization: Bearer <api_token>' \
  -d '{
    "Action": "DeletePagesProject",
    "ProjectId": "<project_id>"
  }'
```

**Example:**

```bash
curl -X POST 'https://pages-api.cloud.tencent.com/v1' \
  -H 'Content-Type: application/json' \
  -H 'Authorization: Bearer eo_api_xxxxxxxxxxxxx' \
  -d '{
    "Action": "DeletePagesProject",
    "ProjectId": "pages-abc123"
  }'
```

**After successful deletion**, retry the deployment:

```bash
edgeone pages deploy [path] -n <project-name> -e preview
```

**Important notes:**
- The deletion is **irreversible**. Always confirm with the user before deleting.
- If the user doesn't know their Project IDs, guide them to the console: https://edgeone.ai/pages
- After deleting, wait a few seconds before retrying the deploy.

---

### Remote Build Timeout (ConnectTimeoutError)

If deployment fails with errors like:
- `ConnectTimeoutError: Connect Timeout Error`
- `fetch failed` during build
- `mirrors.tencent.com:443 timeout`

This means the remote build environment has network issues. **Always fall back to local build:**

1. Build locally:
```bash
npm install
npm run build
```

2. Deploy the build output:
```bash
edgeone pages deploy ./dist -n <project-name> -e preview
```

**Tell the user:**
```
The remote build encountered a network timeout. I've built the project locally instead and will deploy the build output directly. This is more reliable.
```

---

### CLI Installation Fails

If `npm install -g edgeone` fails due to permissions:

```bash
# Try with sudo (macOS / Linux)
sudo npm install -g edgeone

# Or use npx instead (no global install needed)
npx edgeone pages deploy [path]
```

### Authentication Fails

If `edgeone login` fails or times out:

```
Browser login failed. You can use an API Token instead:
1. Go to EdgeOne Pages console to generate an API Token
2. Deploy with: edgeone pages deploy -n <project-name> -t <your-api-token>
```

### Build Fails

If the build fails during deployment:

1. Try building locally first to see the error:
```bash
npm run build
```

2. If the build succeeds locally, deploy the build output directly:
```bash
edgeone pages deploy ./dist -e preview
```

### Account Switching

If the user needs to switch to a different Tencent Cloud account:

```bash
edgeone switch
```

---

## Agent-Specific Notes

### Terminal-based agents (Claude Code, Cursor, etc.)

You have full shell access. Follow the decision flow above using the CLI directly. Always check CLI status first before attempting any deployment.

### Sandboxed environments

If in a sandboxed environment where `edgeone login` is not possible, guide the user to use API Token authentication:

```bash
edgeone pages deploy [path] -n <project-name> -t <api-token> -e preview
```

### Quick Reference

| Command                              | Description                        |
|--------------------------------------|------------------------------------|
| `npm install -g edgeone`             | Install EdgeOne CLI                |
| `edgeone login`                      | Authenticate via browser           |
| `edgeone whoami`                     | Check current authentication       |
| `edgeone pages deploy`               | Deploy (production, auto-build)    |
| `edgeone pages deploy -e preview`    | Deploy as preview                  |
| `edgeone pages deploy ./dist`        | Deploy specific directory          |
| `edgeone pages deploy -n name`       | Deploy to specific project         |
| `edgeone pages deploy -t <token>`    | Deploy with API Token              |
| `edgeone pages link`                 | Link local project                 |
| `edgeone pages env ls`               | List environment variables         |
| `edgeone switch`                     | Switch Tencent Cloud account       |
