#!/bin/bash

#################################################################################
# Kubernetes Resource Optimization POC - Setup Script
# 
# This script sets up the initial environment and prerequisites for the
# kube-green resource optimization system.
#
# Usage: ./scripts/setup.sh [options]
# 
# Options: --interactive, --config-file PATH, --skip-validation, --verbose
#################################################################################

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONFIG_FILE=""
INTERACTIVE=false
SKIP_VALIDATION=false
VERBOSE=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration variables
KUBECONFIG_PATH=""
ARGOCD_SERVER=""
ARGOCD_USERNAME=""
ARGOCD_PASSWORD=""
GITLAB_TOKEN=""
GITLAB_PROJECT_ID=""
SLACK_BOT_TOKEN=""
SLACK_SIGNING_SECRET=""
SLACK_APP_TOKEN=""
SLACK_WEBHOOK_URL=""
ENVIRONMENT="staging"

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Print usage information
usage() {
    cat << EOF
Kubernetes Resource Optimization POC - Setup Script

Usage: $0 [options]

Options:
    --interactive       Run in interactive mode to configure all settings
    --config-file PATH  Load configuration from file
    --skip-validation   Skip validation of external services
    --verbose           Enable verbose output
    --help             Show this help message

Examples:
    $0 --interactive
    $0 --config-file config.yaml
    $0 --skip-validation

Environment Variables:
    KUBECONFIG          Path to kubeconfig file
    ARGOCD_SERVER       ArgoCD server URL
    ARGOCD_USERNAME     ArgoCD username
    ARGOCD_PASSWORD     ArgoCD password
    GITLAB_TOKEN        GitLab API token
    GITLAB_PROJECT_ID   GitLab project ID
    SLACK_BOT_TOKEN     Slack bot token
    SLACK_SIGNING_SECRET Slack signing secret
    SLACK_APP_TOKEN     Slack app token
    SLACK_WEBHOOK_URL   Slack webhook URL

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --interactive)
                INTERACTIVE=true
                shift
                ;;
            --config-file)
                CONFIG_FILE="$2"
                shift 2
                ;;
            --skip-validation)
                SKIP_VALIDATION=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                set -x
                shift
                ;;
            --help)
                usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
}

# Load configuration from file
load_config_file() {
    if [[ -n "$CONFIG_FILE" && -f "$CONFIG_FILE" ]]; then
        log_info "Loading configuration from $CONFIG_FILE"
        
        # Source the config file if it's a shell script
        if [[ "$CONFIG_FILE" == *.sh ]]; then
            # shellcheck source=/dev/null
            source "$CONFIG_FILE"
        elif [[ "$CONFIG_FILE" == *.yaml || "$CONFIG_FILE" == *.yml ]]; then
            # Parse YAML file using yq
            if command -v yq &> /dev/null; then
                KUBECONFIG_PATH=$(yq e '.kubeconfig // ""' "$CONFIG_FILE")
                ARGOCD_SERVER=$(yq e '.argocd.server // ""' "$CONFIG_FILE")
                ARGOCD_USERNAME=$(yq e '.argocd.username // ""' "$CONFIG_FILE")
                ARGOCD_PASSWORD=$(yq e '.argocd.password // ""' "$CONFIG_FILE")
                GITLAB_TOKEN=$(yq e '.gitlab.token // ""' "$CONFIG_FILE")
                GITLAB_PROJECT_ID=$(yq e '.gitlab.project_id // ""' "$CONFIG_FILE")
                SLACK_BOT_TOKEN=$(yq e '.slack.bot_token // ""' "$CONFIG_FILE")
                SLACK_SIGNING_SECRET=$(yq e '.slack.signing_secret // ""' "$CONFIG_FILE")
                SLACK_APP_TOKEN=$(yq e '.slack.app_token // ""' "$CONFIG_FILE")
                SLACK_WEBHOOK_URL=$(yq e '.slack.webhook_url // ""' "$CONFIG_FILE")
                ENVIRONMENT=$(yq e '.environment // "staging"' "$CONFIG_FILE")
            else
                log_error "yq is required to parse YAML config files"
                exit 1
            fi
        fi
        
        log_success "Configuration loaded from file"
    fi
}

# Load configuration from environment variables
load_env_config() {
    KUBECONFIG_PATH="${KUBECONFIG:-${KUBECONFIG_PATH:-$HOME/.kube/config}}"
    ARGOCD_SERVER="${ARGOCD_SERVER:-${ARGOCD_SERVER}}"
    ARGOCD_USERNAME="${ARGOCD_USERNAME:-${ARGOCD_USERNAME}}"
    ARGOCD_PASSWORD="${ARGOCD_PASSWORD:-${ARGOCD_PASSWORD}}"
    GITLAB_TOKEN="${GITLAB_TOKEN:-${GITLAB_TOKEN}}"
    GITLAB_PROJECT_ID="${GITLAB_PROJECT_ID:-${GITLAB_PROJECT_ID}}"
    SLACK_BOT_TOKEN="${SLACK_BOT_TOKEN:-${SLACK_BOT_TOKEN}}"
    SLACK_SIGNING_SECRET="${SLACK_SIGNING_SECRET:-${SLACK_SIGNING_SECRET}}"
    SLACK_APP_TOKEN="${SLACK_APP_TOKEN:-${SLACK_APP_TOKEN}}"
    SLACK_WEBHOOK_URL="${SLACK_WEBHOOK_URL:-${SLACK_WEBHOOK_URL}}"
}

# Interactive configuration
interactive_config() {
    if [[ $INTERACTIVE == false ]]; then
        return
    fi
    
    log_info "Starting interactive configuration..."
    
    echo
    echo "=== Kubernetes Configuration ==="
    read -rp "Kubeconfig path [${KUBECONFIG_PATH}]: " input
    KUBECONFIG_PATH="${input:-$KUBECONFIG_PATH}"
    
    echo
    echo "=== ArgoCD Configuration ==="
    read -rp "ArgoCD server URL [${ARGOCD_SERVER}]: " input
    ARGOCD_SERVER="${input:-$ARGOCD_SERVER}"
    
    read -rp "ArgoCD username [${ARGOCD_USERNAME:-admin}]: " input
    ARGOCD_USERNAME="${input:-${ARGOCD_USERNAME:-admin}}"
    
    read -rsp "ArgoCD password: " ARGOCD_PASSWORD
    echo
    
    echo
    echo "=== GitLab Configuration ==="
    read -rp "GitLab token: " GITLAB_TOKEN
    read -rp "GitLab project ID: " GITLAB_PROJECT_ID
    
    echo
    echo "=== Slack Configuration ==="
    read -rp "Slack bot token: " SLACK_BOT_TOKEN
    read -rp "Slack signing secret: " SLACK_SIGNING_SECRET
    read -rp "Slack app token: " SLACK_APP_TOKEN
    read -rp "Slack webhook URL: " SLACK_WEBHOOK_URL
    
    echo
    echo "=== Environment Configuration ==="
    read -rp "Default environment [${ENVIRONMENT}]: " input
    ENVIRONMENT="${input:-$ENVIRONMENT}"
    
    log_success "Interactive configuration completed"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check required tools
    local required_tools=("kubectl" "helm" "yq" "jq" "curl")
    local missing_tools=()
    
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        echo
        echo "Installation instructions:"
        echo "  kubectl: https://kubernetes.io/docs/tasks/tools/install-kubectl/"
        echo "  helm: https://helm.sh/docs/intro/install/"
        echo "  yq: https://github.com/mikefarah/yq#install"
        echo "  jq: https://stedolan.github.io/jq/download/"
        echo "  curl: Usually pre-installed or available via package manager"
        exit 1
    fi
    
    log_success "All required tools are installed"
}

# Validate Kubernetes connection
validate_kubernetes() {
    if [[ $SKIP_VALIDATION == true ]]; then
        log_info "Skipping Kubernetes validation"
        return
    fi
    
    log_info "Validating Kubernetes connection..."
    
    export KUBECONFIG="$KUBECONFIG_PATH"
    
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster"
        log_info "Please check your kubeconfig at: $KUBECONFIG_PATH"
        exit 1
    fi
    
    # Check cluster version
    local k8s_version
    k8s_version=$(kubectl version --short --client -o json | jq -r '.serverVersion.gitVersion' 2>/dev/null || echo "unknown")
    log_success "Connected to Kubernetes cluster (version: $k8s_version)"
    
    # Check for required permissions
    log_info "Checking cluster permissions..."
    
    local permissions=(
        "create namespace"
        "create deployment"
        "create service"
        "create configmap"
        "create secret"
        "create customresourcedefinition"
    )
    
    for perm in "${permissions[@]}"; do
        local resource
        resource=$(echo "$perm" | awk '{print $2}')
        local verb
        verb=$(echo "$perm" | awk '{print $1}')
        
        if kubectl auth can-i "$verb" "$resource" --all-namespaces &> /dev/null; then
            log_success "Permission check passed: $perm"
        else
            log_warning "Permission check failed: $perm"
        fi
    done
}

# Validate ArgoCD connection
validate_argocd() {
    if [[ $SKIP_VALIDATION == true || -z "$ARGOCD_SERVER" ]]; then
        log_info "Skipping ArgoCD validation"
        return
    fi
    
    log_info "Validating ArgoCD connection..."
    
    if command -v argocd &> /dev/null; then
        if argocd version --server "$ARGOCD_SERVER" --username "$ARGOCD_USERNAME" --password "$ARGOCD_PASSWORD" --insecure &> /dev/null; then
            log_success "ArgoCD connection validated"
        else
            log_warning "Cannot connect to ArgoCD server"
        fi
    else
        log_info "ArgoCD CLI not found - will skip validation"
    fi
}

# Validate GitLab connection
validate_gitlab() {
    if [[ $SKIP_VALIDATION == true || -z "$GITLAB_TOKEN" ]]; then
        log_info "Skipping GitLab validation"
        return
    fi
    
    log_info "Validating GitLab connection..."
    
    local response
    response=$(curl -s -H "Authorization: Bearer $GITLAB_TOKEN" "https://gitlab.com/api/v4/user")
    
    if echo "$response" | jq -e '.id' &> /dev/null; then
        local username
        username=$(echo "$response" | jq -r '.username')
        log_success "GitLab connection validated (user: $username)"
    else
        log_warning "Cannot validate GitLab token"
    fi
    
    if [[ -n "$GITLAB_PROJECT_ID" ]]; then
        response=$(curl -s -H "Authorization: Bearer $GITLAB_TOKEN" "https://gitlab.com/api/v4/projects/$GITLAB_PROJECT_ID")
        
        if echo "$response" | jq -e '.id' &> /dev/null; then
            local project_name
            project_name=$(echo "$response" | jq -r '.name')
            log_success "GitLab project validated (project: $project_name)"
        else
            log_warning "Cannot access GitLab project $GITLAB_PROJECT_ID"
        fi
    fi
}

# Validate Slack configuration
validate_slack() {
    if [[ $SKIP_VALIDATION == true || -z "$SLACK_BOT_TOKEN" ]]; then
        log_info "Skipping Slack validation"
        return
    fi
    
    log_info "Validating Slack connection..."
    
    local response
    response=$(curl -s -H "Authorization: Bearer $SLACK_BOT_TOKEN" "https://slack.com/api/auth.test")
    
    if echo "$response" | jq -e '.ok' | grep -q true; then
        local user
        user=$(echo "$response" | jq -r '.user')
        log_success "Slack bot token validated (user: $user)"
    else
        log_warning "Cannot validate Slack bot token"
    fi
    
    if [[ -n "$SLACK_WEBHOOK_URL" ]]; then
        local webhook_response
        webhook_response=$(curl -s -X POST -H 'Content-type: application/json' \
            --data '{"text":"Test message from k8s-resource-optimization setup"}' \
            "$SLACK_WEBHOOK_URL")
        
        if [[ "$webhook_response" == "ok" ]]; then
            log_success "Slack webhook validated"
        else
            log_warning "Cannot validate Slack webhook"
        fi
    fi
}

# Create configuration files
create_config_files() {
    log_info "Creating configuration files..."
    
    # Create .env file for local development
    cat > "${PROJECT_ROOT}/.env" << EOF
# Kubernetes Resource Optimization POC Configuration
# Generated on $(date)

# Kubernetes Configuration
KUBECONFIG=${KUBECONFIG_PATH}

# ArgoCD Configuration
ARGOCD_SERVER=${ARGOCD_SERVER}
ARGOCD_USERNAME=${ARGOCD_USERNAME}
ARGOCD_PASSWORD=${ARGOCD_PASSWORD}

# GitLab Configuration
GITLAB_TOKEN=${GITLAB_TOKEN}
GITLAB_PROJECT_ID=${GITLAB_PROJECT_ID}

# Slack Configuration
SLACK_BOT_TOKEN=${SLACK_BOT_TOKEN}
SLACK_SIGNING_SECRET=${SLACK_SIGNING_SECRET}
SLACK_APP_TOKEN=${SLACK_APP_TOKEN}
SLACK_WEBHOOK_URL=${SLACK_WEBHOOK_URL}

# Environment Configuration
ENVIRONMENT=${ENVIRONMENT}
EOF
    
    log_success "Configuration file created: ${PROJECT_ROOT}/.env"
    
    # Create GitLab CI variables file
    cat > "${PROJECT_ROOT}/gitlab-variables.yaml" << EOF
# GitLab CI/CD Variables for Kubernetes Resource Optimization POC
# Upload these variables to your GitLab project: Settings > CI/CD > Variables

variables:
  - key: KUBECONFIG
    value: ${KUBECONFIG_PATH}
    protected: true
    masked: false
    
  - key: ARGOCD_SERVER
    value: ${ARGOCD_SERVER}
    protected: false
    masked: false
    
  - key: ARGOCD_USERNAME
    value: ${ARGOCD_USERNAME}
    protected: true
    masked: false
    
  - key: ARGOCD_PASSWORD
    value: ${ARGOCD_PASSWORD}
    protected: true
    masked: true
    
  - key: GITLAB_TOKEN
    value: ${GITLAB_TOKEN}
    protected: true
    masked: true
    
  - key: GITLAB_PROJECT_ID
    value: ${GITLAB_PROJECT_ID}
    protected: false
    masked: false
    
  - key: SLACK_BOT_TOKEN
    value: ${SLACK_BOT_TOKEN}
    protected: true
    masked: true
    
  - key: SLACK_SIGNING_SECRET
    value: ${SLACK_SIGNING_SECRET}
    protected: true
    masked: true
    
  - key: SLACK_APP_TOKEN
    value: ${SLACK_APP_TOKEN}
    protected: true
    masked: true
    
  - key: SLACK_WEBHOOK_URL
    value: ${SLACK_WEBHOOK_URL}
    protected: true
    masked: false
EOF
    
    log_success "GitLab variables file created: ${PROJECT_ROOT}/gitlab-variables.yaml"
    
    # Create Kubernetes secrets template
    "${SCRIPT_DIR}/create-secrets.sh" || log_warning "Failed to create Kubernetes secrets"
}

# Create secrets script
create_secrets_script() {
    cat > "${PROJECT_ROOT}/scripts/create-secrets.sh" << 'EOF'
#!/bin/bash

# Create Kubernetes secrets for the POC
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Load environment variables
if [[ -f "${PROJECT_ROOT}/.env" ]]; then
    # shellcheck source=/dev/null
    source "${PROJECT_ROOT}/.env"
fi

# Create namespace
kubectl create namespace kube-green-system --dry-run=client -o yaml | kubectl apply -f -

# Create secrets
kubectl create secret generic slack-webhook-secrets \
    --from-literal=SLACK_BOT_TOKEN="${SLACK_BOT_TOKEN}" \
    --from-literal=SLACK_SIGNING_SECRET="${SLACK_SIGNING_SECRET}" \
    --from-literal=SLACK_APP_TOKEN="${SLACK_APP_TOKEN}" \
    --from-literal=GITLAB_TOKEN="${GITLAB_TOKEN}" \
    --from-literal=ARGOCD_TOKEN="${ARGOCD_PASSWORD}" \
    -n kube-green-system \
    --dry-run=client -o yaml | kubectl apply -f -

echo "✅ Secrets created successfully"
EOF
    
    chmod +x "${PROJECT_ROOT}/scripts/create-secrets.sh"
}

# Main setup function
main() {
    log_info "Starting Kubernetes Resource Optimization POC setup"
    
    # Step 1: Check prerequisites
    check_prerequisites
    
    # Step 2: Load configuration
    load_config_file
    load_env_config
    interactive_config
    
    # Step 3: Validate connections
    validate_kubernetes
    validate_argocd
    validate_gitlab
    validate_slack
    
    # Step 4: Create configuration files
    create_secrets_script
    create_config_files
    
    log_success "Setup completed successfully!"
    
    # Print next steps
    cat << EOF

${GREEN}🎉 Setup Complete!${NC}

Configuration files created:
• ${PROJECT_ROOT}/.env (local environment variables)
• ${PROJECT_ROOT}/gitlab-variables.yaml (GitLab CI/CD variables)
• ${PROJECT_ROOT}/scripts/create-secrets.sh (Kubernetes secrets)

Next steps:
1. Review the configuration files and adjust as needed
2. Upload GitLab variables to your project: Settings > CI/CD > Variables
3. Run the secrets creation script: ./scripts/create-secrets.sh
4. Deploy the system: ./scripts/deploy.sh ${ENVIRONMENT}

Documentation: ${PROJECT_ROOT}/docs/
Deployment script: ${PROJECT_ROOT}/scripts/deploy.sh

EOF
}

# Parse arguments and run main function
parse_args "$@"
main
