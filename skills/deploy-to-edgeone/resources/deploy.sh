#!/bin/bash
# EdgeOne Pages Deploy Script
# This script handles deployment to EdgeOne Pages with automatic
# framework detection, building, and deployment.
#
# Usage:
#   bash deploy.sh [path] [options]
#
# Arguments:
#   path          - Directory or ZIP to deploy (defaults to current directory)
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
#   bash deploy.sh ./dist
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
DEPLOY_PATH=""
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
            echo "Usage: bash deploy.sh [path] [options]"
            echo ""
            echo "Arguments:"
            echo "  path                  Directory or ZIP to deploy (defaults to .)"
            echo ""
            echo "Options:"
            echo "  -n, --name NAME       Project name"
            echo "  -t, --token TOKEN     API Token for authentication"
            echo "  -e, --env ENV         Environment: production or preview (default: preview)"
            echo "  --delete              Delete a project (requires -t and --project-id)"
            echo "  --project-id ID       Project ID to delete (format: pages-xxxxx)"
            echo "  -h, --help            Show this help message"
            echo ""
            echo "Examples:"
            echo "  bash deploy.sh ./dist -n my-project -e preview"
            echo "  bash deploy.sh --delete --project-id pages-xxxxx -t YOUR_TOKEN"
            exit 0
            ;;
        *)
            if [[ -z "$DEPLOY_PATH" ]]; then
                DEPLOY_PATH="$1"
            fi
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
            echo "  1. Go to EdgeOne Pages console"
            echo "  2. Generate an API Token"
            echo "  3. Re-run: bash deploy.sh -t <your-token>"
            exit 1
        fi
    fi
}

# ============================================================
# Auto-detect project name from package.json
# ============================================================
detect_project_name() {
    if [[ -z "$PROJECT_NAME" ]]; then
        local project_dir="${DEPLOY_PATH:-.}"

        # If deploy path is a build output dir, look in parent
        local basename
        basename=$(basename "$project_dir")
        if [[ "$basename" == "dist" || "$basename" == "build" || "$basename" == "out" || "$basename" == ".next" || "$basename" == ".output" ]]; then
            local parent_dir
            parent_dir=$(dirname "$project_dir")
            if [[ -f "$parent_dir/package.json" ]]; then
                PROJECT_NAME=$(grep -o '"name": *"[^"]*"' "$parent_dir/package.json" 2>/dev/null | head -1 | sed 's/"name": *"//;s/"//')
            fi
        fi

        # Try current directory package.json
        if [[ -z "$PROJECT_NAME" ]] && [[ -f "package.json" ]]; then
            PROJECT_NAME=$(grep -o '"name": *"[^"]*"' "package.json" 2>/dev/null | head -1 | sed 's/"name": *"//;s/"//')
        fi

        # Try deploy path package.json
        if [[ -z "$PROJECT_NAME" ]] && [[ -f "$project_dir/package.json" ]]; then
            PROJECT_NAME=$(grep -o '"name": *"[^"]*"' "$project_dir/package.json" 2>/dev/null | head -1 | sed 's/"name": *"//;s/"//')
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
# Detect framework and build locally (ALWAYS prefer local build)
# ============================================================
detect_and_build() {
    log_step "Checking build output..."

    local project_dir="."

    # If deploy path is explicitly a build output or ZIP, use it directly
    if [[ -n "$DEPLOY_PATH" ]]; then
        if [[ "$DEPLOY_PATH" == *.zip ]]; then
            log_info "Deploy path is a ZIP file: $DEPLOY_PATH"
            return 0
        fi

        local basename
        basename=$(basename "$DEPLOY_PATH")
        if [[ "$basename" == "dist" || "$basename" == "build" || "$basename" == "out" || "$basename" == ".next" || "$basename" == ".output" ]]; then
            if [[ -d "$DEPLOY_PATH" ]]; then
                log_info "Deploy path is a build output directory: $DEPLOY_PATH"
                return 0
            fi
        fi

        # If deploy path is a project directory (has package.json), use it as project_dir
        if [[ -f "$DEPLOY_PATH/package.json" ]]; then
            project_dir="$DEPLOY_PATH"
        fi
    fi

    # Check for existing build output
    for dir in dist build out .next .output; do
        if [[ -d "$project_dir/$dir" ]]; then
            log_info "Found existing build output: $project_dir/$dir"
            DEPLOY_PATH="$project_dir/$dir"
            return 0
        fi
    done

    # No build output — try to build locally
    if [[ -f "$project_dir/package.json" ]]; then
        local has_build
        has_build=$(grep -c '"build"' "$project_dir/package.json" 2>/dev/null || echo "0")

        if [[ "$has_build" -gt 0 ]]; then
            log_warn "No build output found. Building locally first (recommended over remote build)..."

            # Install dependencies if needed
            if [[ ! -d "$project_dir/node_modules" ]]; then
                log_info "Installing dependencies..."
                (cd "$project_dir" && npm install)
            fi

            # Run build
            log_step "Running local build..."
            (cd "$project_dir" && npm run build)

            # Find build output
            for dir in dist build out .next .output; do
                if [[ -d "$project_dir/$dir" ]]; then
                    DEPLOY_PATH="$project_dir/$dir"
                    log_success "Local build completed: $DEPLOY_PATH"
                    return 0
                fi
            done

            log_warn "Build completed but no standard output directory found. Will let EdgeOne CLI auto-detect."
        fi
    fi

    # Fallback — use project root or deploy path as-is
    if [[ -z "$DEPLOY_PATH" ]]; then
        DEPLOY_PATH="."
    fi
    log_info "Will deploy: $DEPLOY_PATH"
}

# ============================================================
# Deploy with error handling
# ============================================================
deploy() {
    log_step "Deploying to EdgeOne Pages..."
    echo ""

    # Build the command
    local cmd="edgeone pages deploy"

    if [[ -n "$DEPLOY_PATH" ]]; then
        cmd="$cmd $DEPLOY_PATH"
    fi

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

    # Execute deployment and capture output
    local output
    local exit_code
    set +e
    output=$(eval "$cmd" 2>&1)
    exit_code=$?
    set -e

    echo "$output"

    if [[ $exit_code -eq 0 ]]; then
        echo ""
        log_success "Deployment successful! 🎉"
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
        echo "  Use this script to delete a project:"
        echo "  bash deploy.sh --delete --project-id pages-xxxxx -t YOUR_API_TOKEN"
        echo ""
        echo "  To get an API Token, go to the EdgeOne Pages console settings."
        echo ""
        exit 1
    fi

    # Check for build timeout / network errors
    if echo "$output" | grep -qi "ConnectTimeoutError\|fetch failed\|timeout\|ETIMEDOUT\|ECONNREFUSED"; then
        echo ""
        log_error "Remote build failed due to network timeout."
        echo ""
        echo "  The remote build environment couldn't fetch dependencies."
        echo "  Trying local build instead..."
        echo ""

        # Attempt local build and redeploy
        local project_dir="."
        if [[ -f "$project_dir/package.json" ]]; then
            log_step "Building locally..."
            (cd "$project_dir" && npm install && npm run build)

            # Find build output
            for dir in dist build out .next .output; do
                if [[ -d "$project_dir/$dir" ]]; then
                    DEPLOY_PATH="$project_dir/$dir"
                    log_success "Local build completed: $DEPLOY_PATH"
                    echo ""
                    log_step "Retrying deploy with local build output..."

                    local retry_cmd="edgeone pages deploy $DEPLOY_PATH"
                    [[ -n "$PROJECT_NAME" ]] && retry_cmd="$retry_cmd -n $PROJECT_NAME"
                    [[ -n "$API_TOKEN" ]] && retry_cmd="$retry_cmd -t $API_TOKEN"
                    [[ "$DEPLOY_ENV" == "preview" ]] && retry_cmd="$retry_cmd -e preview"

                    log_info "Running: $retry_cmd"
                    eval "$retry_cmd"
                    local retry_exit=$?

                    if [[ $retry_exit -eq 0 ]]; then
                        echo ""
                        log_success "Deployment successful (with local build)! 🎉"
                        return 0
                    else
                        log_error "Retry also failed with exit code $retry_exit"
                        exit $retry_exit
                    fi
                fi
            done
        fi

        log_error "Could not build locally. Please build manually and deploy the output directory."
        exit 1
    fi

    # Generic failure
    echo ""
    log_error "Deployment failed with exit code $exit_code"
    echo ""
    echo "  Troubleshooting:"
    echo "  - Check if the build output directory exists"
    echo "  - Verify your authentication: edgeone whoami"
    echo "  - Try building locally first: npm run build"
    echo "  - Then deploy: edgeone pages deploy ./dist -n $PROJECT_NAME -e preview"
    exit $exit_code
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
    detect_and_build
    deploy
}

main
