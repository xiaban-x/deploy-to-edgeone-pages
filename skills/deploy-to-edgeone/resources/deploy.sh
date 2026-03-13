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
#
# Examples:
#   bash deploy.sh
#   bash deploy.sh ./dist
#   bash deploy.sh -n my-project -e preview
#   bash deploy.sh -n my-project -t $EDGEONE_API_TOKEN

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
DEPLOY_PATH=""
PROJECT_NAME=""
API_TOKEN=""
DEPLOY_ENV="preview"

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
        -h|--help)
            echo "Usage: bash deploy.sh [path] [options]"
            echo ""
            echo "Arguments:"
            echo "  path              Directory or ZIP to deploy (defaults to .)"
            echo ""
            echo "Options:"
            echo "  -n, --name NAME   Project name"
            echo "  -t, --token TOKEN API Token for authentication"
            echo "  -e, --env ENV     Environment: production or preview (default: preview)"
            echo "  -h, --help        Show this help message"
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
    echo -e "${BLUE}ℹ${NC} $1"
}

log_success() {
    echo -e "${GREEN}✅${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}⚠️${NC} $1"
}

log_error() {
    echo -e "${RED}❌${NC} $1"
}

# Step 1: Check if EdgeOne CLI is installed
check_cli() {
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
        log_info "EdgeOne CLI found: $(edgeone -v 2>/dev/null || echo 'version unknown')"
    fi
}

# Step 2: Check authentication
check_auth() {
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
        echo "You have two options:"
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
            echo "Please provide an API Token:"
            echo "  1. Go to EdgeOne Pages console"
            echo "  2. Generate an API Token"
            echo "  3. Re-run: bash deploy.sh -t <your-token>"
            exit 1
        fi
    fi
}

# Step 3: Detect framework and build output
detect_build_output() {
    local project_dir="${DEPLOY_PATH:-.}"

    # If deploy path is already a dist/build directory, use it directly
    if [[ -n "$DEPLOY_PATH" ]] && [[ -d "$DEPLOY_PATH" ]]; then
        local basename=$(basename "$DEPLOY_PATH")
        if [[ "$basename" == "dist" || "$basename" == "build" || "$basename" == "out" || "$basename" == ".output" ]]; then
            log_info "Deploy path appears to be a build output directory: $DEPLOY_PATH"
            return 0
        fi
    fi

    # If deploy path is a ZIP, use it directly
    if [[ -n "$DEPLOY_PATH" ]] && [[ "$DEPLOY_PATH" == *.zip ]]; then
        log_info "Deploy path is a ZIP file: $DEPLOY_PATH"
        return 0
    fi

    # Check if package.json exists and has a build script
    if [[ -f "$project_dir/package.json" ]]; then
        local has_build=$(grep -c '"build"' "$project_dir/package.json" 2>/dev/null || echo "0")

        if [[ "$has_build" -gt 0 ]]; then
            # Check for existing build output
            for dir in dist build out .next .output; do
                if [[ -d "$project_dir/$dir" ]]; then
                    log_info "Found existing build output: $project_dir/$dir"
                    if [[ -z "$DEPLOY_PATH" ]]; then
                        DEPLOY_PATH="$project_dir/$dir"
                        log_info "Will deploy: $DEPLOY_PATH"
                    fi
                    return 0
                fi
            done

            # No build output found, need to build
            log_info "No build output found. Building project..."

            # Install dependencies if needed
            if [[ ! -d "$project_dir/node_modules" ]]; then
                log_info "Installing dependencies..."
                (cd "$project_dir" && npm install)
            fi

            # Run build
            log_info "Running build..."
            (cd "$project_dir" && npm run build)

            # Check for build output again
            for dir in dist build out .next .output; do
                if [[ -d "$project_dir/$dir" ]]; then
                    if [[ -z "$DEPLOY_PATH" ]]; then
                        DEPLOY_PATH="$project_dir/$dir"
                        log_info "Build output: $DEPLOY_PATH"
                    fi
                    return 0
                fi
            done
        fi
    fi

    # If nothing found, let EdgeOne CLI handle it
    if [[ -z "$DEPLOY_PATH" ]]; then
        DEPLOY_PATH="."
        log_info "No specific build output detected. EdgeOne CLI will auto-detect."
    fi
}

# Step 4: Deploy
deploy() {
    log_info "Deploying to EdgeOne Pages..."
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

    # Execute deployment
    eval "$cmd"
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        echo ""
        log_success "Deployment successful! 🎉"
    else
        echo ""
        log_error "Deployment failed with exit code $exit_code"
        echo ""
        echo "Troubleshooting:"
        echo "  - Check if the build output directory exists"
        echo "  - Verify your authentication: edgeone whoami"
        echo "  - Try deploying with verbose output"
        exit $exit_code
    fi
}

# Auto-detect project name from package.json if not provided
detect_project_name() {
    if [[ -z "$PROJECT_NAME" ]]; then
        local project_dir="${DEPLOY_PATH:-.}"

        # Try to get name from package.json
        if [[ -f "$project_dir/package.json" ]]; then
            PROJECT_NAME=$(grep -o '"name": *"[^"]*"' "$project_dir/package.json" 2>/dev/null | head -1 | sed 's/"name": *"//;s/"//')
        fi

        # If still no name, use directory name
        if [[ -z "$PROJECT_NAME" ]]; then
            PROJECT_NAME=$(basename "$(pwd)")
        fi

        # Clean up project name (replace special chars with hyphens)
        PROJECT_NAME=$(echo "$PROJECT_NAME" | sed 's/[^a-zA-Z0-9-]/-/g' | sed 's/--*/-/g' | sed 's/^-//;s/-$//')

        log_info "Auto-detected project name: $PROJECT_NAME"
    fi
}

# Main execution
main() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  EdgeOne Pages Deploy"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    check_cli
    check_auth
    detect_project_name
    detect_build_output
    deploy
}

main
