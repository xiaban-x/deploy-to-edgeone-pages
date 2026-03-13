#!/bin/bash
# EdgeOne Pages Deploy Script
# This script handles deployment to EdgeOne Pages with automatic
# framework detection, building, and deployment.
#
# Deploy flow:
#   1. edgeone pages deploy (remote build + deploy)
#   2. If fails (timeout/network) → edgeone pages build (local build)
#   3. Then → edgeone pages deploy .edgeone (deploy local build output)
#
# Usage:
#   bash deploy.sh [options]
#
# Options:
#   -n, --name    - Project name
#   -t, --token   - API Token for authentication
#   -e, --env     - Environment: production (default) or preview
#   --delete      - Delete a project by ID (requires -t and --project-id)
#   --project-id  - Project ID for deletion (format: pages-xxxxx)
#
# Examples:
#   bash deploy.sh
#   bash deploy.sh -n my-project -e preview
#   bash deploy.sh -n my-project -t $EDGEONE_API_TOKEN
#   bash deploy.sh --delete --project-id pages-xxxxx -t $EDGEONE_API_TOKEN

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default values
PROJECT_NAME=""
API_TOKEN=""
DEPLOY_ENV="preview"
DELETE_MODE=false
DELETE_PROJECT_ID=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--name)
            PROJECT_NAME="$2"
            shift 2
            ;;
        -t|--token)
            API_TOKEN="$2"
            shift 2
            ;;
        -e|--env)
            DEPLOY_ENV="$2"
            shift 2
            ;;
        --delete)
            DELETE_MODE=true
            shift
            ;;
        --project-id)
            DELETE_PROJECT_ID="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: bash deploy.sh [options]"
            echo ""
            echo "Options:"
            echo "  -n, --name NAME       Project name"
            echo "  -t, --token TOKEN     API Token for authentication"
            echo "  -e, --env ENV         Environment: production or preview (default: preview)"
            echo "  --delete              Delete a project (requires -t and --project-id)"
            echo "  --project-id ID       Project ID to delete (format: pages-xxxxx)"
            echo "  -h, --help            Show this help message"
            echo ""
            echo "Deploy flow:"
            echo "  1. Try: edgeone pages deploy (remote build)"
            echo "  2. If timeout: edgeone pages build (local build)"
            echo "  3. Then: edgeone pages deploy .edgeone"
            echo ""
            echo "Examples:"
            echo "  bash deploy.sh -n my-project -e preview"
            echo "  bash deploy.sh --delete --project-id pages-xxxxx -t YOUR_TOKEN"
            exit 0
            ;;
        *)
            shift
            ;;
    esac
done

# Helper functions
log_info() {
    echo -e "${BLUE}ℹ${NC}  $1"
}

log_success() {
    echo -e "${GREEN}✅${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}⚠️${NC}  $1"
}

log_error() {
    echo -e "${RED}❌${NC} $1"
}

log_step() {
    echo -e "${CYAN}▶${NC}  $1"
}

# ============================================================
# Delete Project via API
# ============================================================
delete_project() {
    if [[ -z "$API_TOKEN" ]]; then
        log_error "API Token is required for project deletion."
        echo "  Usage: bash deploy.sh --delete --project-id pages-xxxxx -t YOUR_TOKEN"
        echo ""
        echo "  Get your API Token here:"
        echo "  - China site: https://console.cloud.tencent.com/edgeone/pages?tab=settings"
        echo "  - Global site: https://console.tencentcloud.com/edgeone/pages?tab=settings"
        exit 1
    fi

    if [[ -z "$DELETE_PROJECT_ID" ]]; then
        log_error "Project ID is required for deletion."
        echo "  Usage: bash deploy.sh --delete --project-id pages-xxxxx -t YOUR_TOKEN"
        exit 1
    fi

    log_warn "You are about to delete project: ${DELETE_PROJECT_ID}"
    echo -e "  ${RED}This action is irreversible!${NC}"
    echo ""

    log_step "Calling DeletePagesProject API..."

    local response
    response=$(curl -s -X POST 'https://pages-api.cloud.tencent.com/v1' \
        -H 'Content-Type: application/json' \
        -H "Authorization: Bearer ${API_TOKEN}" \
        -d "{
            \"Action\": \"DeletePagesProject\",
            \"ProjectId\": \"${DELETE_PROJECT_ID}\"
        }" 2>&1)

    local exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
        log_error "API request failed."
        echo "  $response"
        exit 1
    fi

    # Check for errors in response
    local has_error
    has_error=$(echo "$response" | grep -ci '"error"' 2>/dev/null || echo "0")

    if [[ "$has_error" -gt 0 ]]; then
        log_error "Failed to delete project ${DELETE_PROJECT_ID}:"
        echo "  $response"
        exit 1
    else
        log_success "Project ${DELETE_PROJECT_ID} deleted successfully!"
        echo ""
        echo "  Response: $response"
    fi
}

# ============================================================
# Check if EdgeOne CLI is installed
# ============================================================
check_cli() {
    log_step "Checking EdgeOne CLI..."

    if ! command -v edgeone &>/dev/null; then
        log_warn "EdgeOne CLI is not installed. Installing..."
        npm install -g edgeone
        if ! command -v edgeone &>/dev/null; then
            log_error "Failed to install EdgeOne CLI. Please install manually:"
            echo "  npm install -g edgeone"
            exit 1
        fi
        log_success "EdgeOne CLI installed successfully."
    else
        local version
        version=$(edgeone -v 2>/dev/null | grep -o 'version [0-9.a-z-]*' | head -1 || echo 'version unknown')
        log_success "EdgeOne CLI found ($version)"
    fi
}

# ============================================================
# Check authentication
# ============================================================
check_auth() {
    log_step "Checking authentication..."

    # If API token is provided, skip auth check
    if [[ -n "$API_TOKEN" ]]; then
        log_info "Using API Token for authentication."
        return 0
    fi

    # Check if authenticated
    if edgeone whoami &>/dev/null; then
        log_success "EdgeOne CLI is authenticated."
        return 0
    else
        log_warn "EdgeOne CLI is not authenticated."
        echo ""
        echo "  You have two options:"
        echo "  1. Run 'edgeone login' to authenticate via browser"
        echo "  2. Provide an API Token with -t flag"
        echo "     Get your API Token here:"
        echo "     - China site: https://console.cloud.tencent.com/edgeone/pages?tab=settings"
        echo "     - Global site: https://console.tencentcloud.com/edgeone/pages?tab=settings"
        echo ""

        # Try browser login
        log_info "Attempting browser login..."
        if edgeone login; then
            log_success "Authentication successful!"
            return 0
        else
            log_error "Browser login failed."
            echo ""
            echo "  Please provide an API Token:"
            echo "  1. Get your API Token here:"
            echo "     - China site: https://console.cloud.tencent.com/edgeone/pages?tab=settings"
            echo "     - Global site: https://console.tencentcloud.com/edgeone/pages?tab=settings"
            echo "  2. Re-run: bash deploy.sh -t <your-token>"
            exit 1
        fi
    fi
}

# ============================================================
# Auto-detect project name from package.json
# ============================================================
detect_project_name() {
    if [[ -z "$PROJECT_NAME" ]]; then
        # Try current directory package.json
        if [[ -f "package.json" ]]; then
            PROJECT_NAME=$(grep -o '"name": *"[^"]*"' "package.json" 2>/dev/null | head -1 | sed 's/"name": *"//;s/"//')
        fi

        # Fallback to directory name
        if [[ -z "$PROJECT_NAME" ]]; then
            PROJECT_NAME=$(basename "$(pwd)")
        fi

        # Clean up project name (replace special chars with hyphens)
        PROJECT_NAME=$(echo "$PROJECT_NAME" | sed 's/[^a-zA-Z0-9-]/-/g' | sed 's/--*/-/g' | sed 's/^-//;s/-$//')

        log_info "Auto-detected project name: $PROJECT_NAME"
    fi
}

# ============================================================
# Deploy with fallback: deploy → build → deploy .edgeone
# ============================================================
deploy() {
    log_step "Deploying to EdgeOne Pages..."
    echo ""

    # Build the deploy command (no path = remote build)
    local cmd="edgeone pages deploy"

    if [[ -n "$PROJECT_NAME" ]]; then
        cmd="$cmd -n $PROJECT_NAME"
    fi

    if [[ -n "$API_TOKEN" ]]; then
        cmd="$cmd -t $API_TOKEN"
    fi

    if [[ "$DEPLOY_ENV" == "preview" ]]; then
        cmd="$cmd -e preview"
    fi

    log_info "Running: $cmd"
    echo ""

    # Step 1: Try direct deploy (remote build)
    local output
    local exit_code
    set +e
    output=$(eval "$cmd" 2>&1)
    exit_code=$?
    set -e

    echo "$output"

    if [[ $exit_code -eq 0 ]]; then
        echo ""
        handle_success "$output"
        return 0
    fi

    # ---- Error handling ----

    # Check for project limit exceeded
    if echo "$output" | grep -qi "exceeds 40 limit\|project limit\|exceeds.*limit"; then
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        log_error "Project limit exceeded! Your account has reached the maximum of 40 projects."
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "  You have two options to resolve this:"
        echo ""
        echo "  ${CYAN}Option 1: Delete via Console (recommended)${NC}"
        echo "  Go to the EdgeOne Pages console to manage and delete projects:"
        echo "  👉 https://edgeone.ai/pages"
        echo ""
        echo "  ${CYAN}Option 2: Delete via API${NC}"
        echo "  Provide your API Token and Project ID, and I can delete them for you."
        echo "  Get your API Token here:"
        echo "  - China site: https://console.cloud.tencent.com/edgeone/pages?tab=settings"
        echo "  - Global site: https://console.tencentcloud.com/edgeone/pages?tab=settings"
        echo ""
        echo "  Then run:"
        echo "  bash deploy.sh --delete --project-id pages-xxxxx -t YOUR_API_TOKEN"
        echo ""
        exit 1
    fi

    # Check for build timeout / network errors → fallback to local build
    if echo "$output" | grep -qi "ConnectTimeoutError\|fetch failed\|timeout\|ETIMEDOUT\|ECONNREFUSED"; then
        echo ""
        log_warn "Remote build failed due to network timeout. Falling back to local build..."
        echo ""

        # Step 2: Build locally using edgeone pages build
        log_step "Running: edgeone pages build"
        set +e
        local build_output
        build_output=$(edgeone pages build 2>&1)
        local build_exit=$?
        set -e

        echo "$build_output"

        if [[ $build_exit -ne 0 ]]; then
            log_error "Local build also failed."
            echo "  Please check the build errors above and fix them."
            exit $build_exit
        fi

        log_success "Local build completed!"
        echo ""

        # Step 3: Deploy the .edgeone build output
        local retry_cmd="edgeone pages deploy .edgeone"
        [[ -n "$PROJECT_NAME" ]] && retry_cmd="$retry_cmd -n $PROJECT_NAME"
        [[ -n "$API_TOKEN" ]] && retry_cmd="$retry_cmd -t $API_TOKEN"
        [[ "$DEPLOY_ENV" == "preview" ]] && retry_cmd="$retry_cmd -e preview"

        log_step "Running: $retry_cmd"
        echo ""

        set +e
        local retry_output
        retry_output=$(eval "$retry_cmd" 2>&1)
        local retry_exit=$?
        set -e

        echo "$retry_output"

        if [[ $retry_exit -eq 0 ]]; then
            echo ""
            handle_success "$retry_output"
            return 0
        else
            log_error "Deployment of local build output also failed (exit code: $retry_exit)."
            exit $retry_exit
        fi
    fi

    # Generic failure
    echo ""
    log_error "Deployment failed with exit code $exit_code"
    echo ""
    echo "  Troubleshooting:"
    echo "  - Verify your authentication: edgeone whoami"
    echo "  - Try local build: edgeone pages build"
    echo "  - Then deploy: edgeone pages deploy .edgeone -n $PROJECT_NAME -e preview"
    exit $exit_code
}

# ============================================================
# Handle successful deployment — parse and display results
# ============================================================
handle_success() {
    local output="$1"

    # Parse deployment info from CLI output
    local deploy_url
    local project_id
    local deploy_type

    deploy_url=$(echo "$output" | grep -o 'EDGEONE_DEPLOY_URL=[^ ]*' | head -1 | sed 's/EDGEONE_DEPLOY_URL=//')
    project_id=$(echo "$output" | grep -o 'EDGEONE_PROJECT_ID=[^ ]*' | head -1 | sed 's/EDGEONE_PROJECT_ID=//')
    deploy_type=$(echo "$output" | grep -o 'EDGEONE_DEPLOY_TYPE=[^ ]*' | head -1 | sed 's/EDGEONE_DEPLOY_TYPE=//')

    log_success "Deployment successful! 🎉"
    echo ""

    if [[ -n "$deploy_url" ]]; then
        echo "  📎 Preview URL (full, with token):"
        echo "  ${GREEN}${deploy_url}${NC}"
        echo ""
    fi

    if [[ -n "$project_id" ]]; then
        echo "  📋 Project ID: $project_id"
    fi

    if [[ -n "$deploy_type" ]]; then
        echo "  📦 Deploy Type: $deploy_type"
    fi

    echo ""
    echo "  ⏰ Note: The preview URL above is valid for 3 hours only."
    echo "     After it expires, you'll need to redeploy to generate a new preview link."
    echo ""
    echo "  💡 Tip: To get a permanent URL, bind a custom domain in the EdgeOne Pages console:"
    echo "     - China site: https://console.cloud.tencent.com/edgeone/pages"
    echo "     - Global site: https://console.tencentcloud.com/edgeone/pages"
}

# ============================================================
# Main execution
# ============================================================
main() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  EdgeOne Pages Deploy"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Handle delete mode
    if [[ "$DELETE_MODE" == true ]]; then
        delete_project
        exit 0
    fi

    # Normal deploy flow
    check_cli
    check_auth
    detect_project_name
    deploy
}

main
