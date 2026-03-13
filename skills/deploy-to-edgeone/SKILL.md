---
name: deploy-to-edgeone
description: Deploy applications and websites to EdgeOne Pages. Use when the user requests deployment actions like "deploy my app", "deploy to EdgeOne", "push this live", or "create a preview deployment".
metadata:
  author: edgeone-pages
  version: "1.0.0"
---

# Deploy to EdgeOne Pages

> **🚨 TOP-LEVEL RULES (MUST FOLLOW — VIOLATIONS CAUSE USER-FACING ERRORS):**
>
> 1. **DEPLOY FLOW:** Run `edgeone pages deploy` **without any build output path** (no `.next`, `dist`, `build`). Do NOT run `npm run build` or check for build artifacts. The CLI handles building automatically. Only use `edgeone pages build` → `edgeone pages deploy .edgeone` as a fallback if the first deploy fails.
>
> 2. **FULL URL:** After deploy, the CLI outputs `EDGEONE_DEPLOY_URL=https://xxx.edgeone.cool?eo_token=xxx&eo_time=xxx`. You **MUST** show the **complete URL including `?eo_token=...&eo_time=...`**. If you truncate it, the user gets a 403 error.
>
> 3. **EXPIRATION:** Always warn that preview URLs expire in **3 hours**, and suggest binding a **custom domain** for a permanent URL.

Deploy any project to EdgeOne Pages. **Always deploy as preview** (not production) unless the user explicitly asks for production.

The goal is to get the user into the best long-term setup: their project linked to EdgeOne Pages with easy CLI deploys. Every method below tries to move the user closer to that state.

## Step 1: Gather Project State

Run these checks before deciding which method to use:

```bash
# 1. Check if EdgeOne CLI is installed
command -v edgeone 2>/dev/null && edgeone -v

# 2. Check if authenticated
edgeone whoami 2>/dev/null
```

> **⚠️ DO NOT** check for build output directories (dist, .next, etc.) or run `npm run build` at this stage.
> The EdgeOne CLI handles building automatically. Go directly to Step 3 for deployment.

## Step 2: Choose a Deploy Method

Based on the checks above, follow the appropriate path:

---

### Path A: CLI installed + authenticated → Deploy directly

This is the ideal state. The CLI is ready to go. **Go directly to Step 3.**

> **⚠️ IMPORTANT: Do NOT manually build the project or look for existing build output.**
> Do NOT run `npm run build` or check for `.next`, `dist`, `build` directories.
> The `edgeone pages deploy` command handles building automatically.
> Just run `edgeone pages deploy` without specifying a build output path — the CLI knows what to do.

**Preview deployment (default):**

```bash
edgeone pages deploy -n <project-name> -e preview
```

**Production deployment (only if user explicitly asks):**

```bash
edgeone pages deploy -n <project-name>
```

> **Note:** EdgeOne Pages defaults to `production` environment. Always pass `-e preview` unless the user explicitly wants production.

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
   - Generate an API Token from the EdgeOne Pages console:
     - China site: https://console.cloud.tencent.com/edgeone/pages?tab=settings
     - Global site: https://console.tencentcloud.com/edgeone/pages?tab=settings
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
1. Go to the EdgeOne Pages console settings:
   - China site: https://console.cloud.tencent.com/edgeone/pages?tab=settings
   - Global site: https://console.tencentcloud.com/edgeone/pages?tab=settings
2. Generate a new API Token
3. Use it with the -t flag for deployment
```

---

## Step 3: Deploy (with automatic fallback to local build)

> **🚨 MANDATORY FLOW — DO NOT SKIP OR REORDER:**
> 1. Run `edgeone pages deploy` **WITHOUT specifying a build output path** (no `.next`, no `dist`, no `build`, no `out`)
> 2. **ONLY IF** step 1 fails with timeout/network error → run `edgeone pages build` → then `edgeone pages deploy .edgeone`
>
> **NEVER** run `npm run build`, `ls -d .next`, or check for existing build artifacts.
> **NEVER** pass a build output directory (like `.next` or `dist`) to `edgeone pages deploy` on the first attempt.
> Let the EdgeOne CLI handle the build process automatically.

The correct deployment flow is: **try direct deploy first** → if it fails (timeout/network error) → **build locally with `edgeone pages build`** → **deploy the `.edgeone` output**.

### 3.1 First attempt: Direct deploy (NO build path)

Always try `edgeone pages deploy` **without a path** first. The CLI will detect the framework, build remotely, and deploy:

```bash
cd <project-directory>
edgeone pages deploy -n <project-name> -e preview
```

**Do NOT** add a build output path like `.next` or `dist`. Just `edgeone pages deploy`.

If this succeeds, you're done! Show the deployment result.

### 3.2 If deploy fails (timeout / network error): Build locally, then deploy

If the first deploy fails with timeout or network errors (e.g., `ConnectTimeoutError`, `fetch failed`, `timeout`), use the EdgeOne CLI's local build command:

**Step 1: Build locally using `edgeone pages build`:**

```bash
edgeone pages build
```

This will build the project locally and output the result to the `.edgeone` directory.

**Step 2: Deploy the `.edgeone` build output:**

```bash
edgeone pages deploy .edgeone -n <project-name> -e preview
```

### 3.3 Complete fallback flow example:

```bash
# Step 1: Try direct deploy (NO build path — let CLI handle everything)
cd /path/to/project
edgeone pages deploy -n my-project -e preview

# If it fails with timeout/network error...

# Step 2: Build locally using EdgeOne CLI
edgeone pages build

# Step 3: Deploy the local build output (ONLY now specify .edgeone path)
edgeone pages deploy .edgeone -n my-project -e preview
```

### Why this flow?

- **Direct deploy** is the simplest and fastest path — let the remote build handle everything
- **`edgeone pages build`** is the official local build command that knows how to handle all frameworks correctly and outputs to `.edgeone`
- Only fall back to local build when remote build has issues (typically network timeouts like `mirrors.tencent.com` timeout)

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

> **🚨 READ THIS CAREFULLY — THESE RULES ARE MANDATORY FOR EVERY DEPLOYMENT OUTPUT**

Always show the user the deployment URL after a successful deploy.

### Rule 1: COMPLETE URL (NEVER truncate)

**⚠️ CRITICAL: The CLI output contains `EDGEONE_DEPLOY_URL=...` — you MUST copy the ENTIRE URL including ALL query parameters (`eo_token` and `eo_time`).** 

If you strip or truncate the URL, the user will get a 403 error and cannot access their site.

**WRONG** ❌ (truncated — user will get 403):
```
https://my-project-xbomg82u4g.edgeone.cool
```

**CORRECT** ✅ (full URL with token):
```
https://my-project-xbomg82u4g.edgeone.cool?eo_token=2ca5320eff8e081f205765860fd69a35&eo_time=1773428045
```

### Rule 2: Preview URL Expiration Warning

**ALWAYS** add this warning after the deployment table:

```
⏰ **Note:** The preview URL above is valid for **3 hours only**. After it expires, you'll need to redeploy to generate a new preview link.
```

### Rule 3: Custom Domain Suggestion

**ALWAYS** add this tip after the expiration warning:

```
💡 **Tip:** To get a permanent URL, go to your project settings in the EdgeOne Pages console and bind a **custom domain**:
- China site: https://console.cloud.tencent.com/edgeone/pages
- Global site: https://console.tencentcloud.com/edgeone/pages
```

### Complete output template:

Parse the CLI output for these variables:
- `EDGEONE_DEPLOY_URL` → full preview URL (MUST include query params)
- `EDGEONE_PROJECT_ID` → project ID
- `EDGEONE_DEPLOY_TYPE` → deployment type

```
🎉 Deployment successful!

| Item            | Details                                                                        |
|-----------------|--------------------------------------------------------------------------------|
| **Status**      | ✅ Ready                                                                       |
| **Preview URL** | <FULL EDGEONE_DEPLOY_URL with ?eo_token=...&eo_time=...>                       |
| **Env**         | Preview / Production                                                           |
| **Project ID**  | <EDGEONE_PROJECT_ID>                                                           |
| **Console**     | https://console.cloud.tencent.com/edgeone/pages/project/<project-id>/deployment|

⏰ **Note:** The preview URL above is valid for **3 hours only**. After it expires, you'll need to redeploy to generate a new preview link.

💡 **Tip:** To get a permanent URL, go to your project settings in the EdgeOne Pages console and bind a **custom domain**:
- China site: https://console.cloud.tencent.com/edgeone/pages
- Global site: https://console.tencentcloud.com/edgeone/pages
```

### Summary of mandatory output rules:
1. **NEVER** truncate `EDGEONE_DEPLOY_URL` — always include `?eo_token=...&eo_time=...` — truncating causes 403
2. **ALWAYS** include the 3-hour expiration warning
3. **ALWAYS** include the custom domain suggestion
4. **Do not** curl or fetch the deployed URL to verify it works. Just return the link.

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
1. Your API Token — you can create one here:
   - China site: https://console.cloud.tencent.com/edgeone/pages?tab=settings
   - Global site: https://console.tencentcloud.com/edgeone/pages?tab=settings
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

This means the remote build environment has network issues. **Fall back to local build using `edgeone pages build`:**

1. Build locally using EdgeOne CLI:
```bash
edgeone pages build
```

2. Deploy the `.edgeone` build output:
```bash
edgeone pages deploy .edgeone -n <project-name> -e preview
```

**Tell the user:**
```
The remote build encountered a network timeout. I'll build the project locally using `edgeone pages build` and then deploy the local build output. This is more reliable.
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
1. Generate an API Token from the EdgeOne Pages console:
   - China site: https://console.cloud.tencent.com/edgeone/pages?tab=settings
   - Global site: https://console.tencentcloud.com/edgeone/pages?tab=settings
2. Deploy with: edgeone pages deploy -n <project-name> -t <your-api-token>
```

### Build Fails

If the build fails during deployment:

1. Try building locally using EdgeOne CLI:
```bash
edgeone pages build
```

2. If EdgeOne build fails, try the standard build:
```bash
npm run build
```

3. Then deploy the build output:
```bash
# If edgeone pages build succeeded:
edgeone pages deploy .edgeone -n <project-name> -e preview

# If npm run build succeeded (use the framework's output dir):
edgeone pages deploy ./dist -n <project-name> -e preview
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
| `edgeone pages deploy .edgeone`      | Deploy local build output          |
| `edgeone pages build`                | Build project locally              |
| `edgeone pages deploy ./dist`        | Deploy specific directory          |
| `edgeone pages deploy -n name`       | Deploy to specific project         |
| `edgeone pages deploy -t <token>`    | Deploy with API Token              |
| `edgeone pages link`                 | Link local project                 |
| `edgeone pages env ls`               | List environment variables         |
| `edgeone switch`                     | Switch Tencent Cloud account       |
