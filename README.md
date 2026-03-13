# EdgeOne Pages Skills

A collection of agent skills for deploying applications to [EdgeOne Pages](https://edgeone.ai/pages).

## Available Skills

### deploy-to-edgeone

Deploy applications and websites to EdgeOne Pages. Supports automatic framework detection, build, and deployment.

**Triggers:** "deploy my app", "deploy to EdgeOne", "push this live", "create a preview deployment"

## Installation

### Install with skills CLI

```bash
# Install this skill to your AI agent
npx skills add <your-github-username>/edgeone-pages-skills

# Install only the deploy skill
npx skills add <your-github-username>/edgeone-pages-skills --skill deploy-to-edgeone

# Install to a specific agent (e.g., claude-code, cursor)
npx skills add <your-github-username>/edgeone-pages-skills -a claude-code

# Install globally (available across all projects)
npx skills add <your-github-username>/edgeone-pages-skills -g
```

### Manual Installation

1. Clone this repository:
```bash
git clone https://github.com/<your-github-username>/edgeone-pages-skills.git
```

2. Install locally:
```bash
npx skills add ./edgeone-pages-skills
```

## Usage

Once installed, the skill is automatically available to your AI agent. Simply ask:

- "Deploy my app to EdgeOne Pages"
- "Deploy this project"
- "Create a preview deployment on EdgeOne"
- "Push this live to EdgeOne Pages"

The agent will:
1. Check if EdgeOne CLI is installed (install if needed)
2. Check authentication (prompt for login or API token)
3. Build the project if necessary
4. Deploy to EdgeOne Pages
5. Return the deployment URL

## Prerequisites

- [Node.js](https://nodejs.org/) (v16+)
- [npm](https://www.npmjs.com/)
- A [Tencent Cloud](https://cloud.tencent.com/) account with EdgeOne Pages access

## EdgeOne CLI Reference

| Command | Description |
|---------|-------------|
| `npm install -g edgeone` | Install EdgeOne CLI |
| `edgeone login` | Authenticate via browser |
| `edgeone whoami` | Check current authentication |
| `edgeone pages deploy` | Deploy (production, auto-build) |
| `edgeone pages deploy -e preview` | Deploy as preview |
| `edgeone pages deploy ./dist` | Deploy specific directory |
| `edgeone pages deploy -n name` | Deploy to specific project |
| `edgeone pages deploy -t <token>` | Deploy with API Token |
| `edgeone pages link` | Link local project |
| `edgeone pages env ls` | List environment variables |
| `edgeone switch` | Switch Tencent Cloud account |

## Documentation

- [EdgeOne CLI Documentation](https://cloud.tencent.com/document/product/1552/127423)
- [EdgeOne Pages](https://edgeone.ai/pages)
- [Skills CLI](https://www.npmjs.com/package/skills)

## License

MIT
# deploy-to-edgeone-pages
