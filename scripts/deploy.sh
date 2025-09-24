#!/bin/bash

#################################################################################
# Kubernetes Resource Optimization POC - Deployment Script
# 
# This script deploys the complete kube-green resource optimization system
# including the operator, Slack integration, and monitoring stack.
#
# Usage: ./scripts/deploy.sh [environment] [options]
# 
# Environments: staging, production, development
# Options: --dry-run, --skip-monitoring, --skip-slack, --verbose
#################################################################################

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENVIRONMENT="${1:-staging}"
DRY_RUN=false
SKIP_MONITORING=false
SKIP_SLACK=false
VERBOSE=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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
Kubernetes Resource Optimization POC - Deployment Script

Usage: $0 [environment] [options]

Environments:
    staging      Deploy to staging environment (default)
    production   Deploy to production environment
    development  Deploy to development environment
    all          Deploy to all environments

Options:
    --dry-run           Perform a dry run without making changes
    --skip-monitoring   Skip monitoring stack deployment
    --skip-slack        Skip Slack integration deployment
    --verbose           Enable verbose output
    --help             Show this help message

Examples:
    $0 staging
    $0 production --dry-run
    $0 all --skip-monitoring
    $0 staging --verbose

Environment Variables:
    KUBECONFIG          Path to kubeconfig file (default: ~/.kube/config)
    ARGOCD_SERVER       ArgoCD server URL
    ARGOCD_TOKEN        ArgoCD authentication token
    GITLAB_TOKEN        GitLab API token
    SLACK_WEBHOOK_URL   Slack webhook URL for notifications

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --skip-monitoring)
                SKIP_MONITORING=true
                shift
                ;;
            --skip-slack)
                SKIP_SLACK=true
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
            staging|production|development|all)
                ENVIRONMENT="$1"
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check required tools
    local required_tools=("kubectl" "helm" "yq" "jq")
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            log_error "$tool is required but not installed"
            exit 1
        fi
    done
    
    # Check kubectl connection
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    
    # Check ArgoCD CLI if available
    if command -v argocd &> /dev/null; then
        log_info "ArgoCD CLI found"
    else
        log_warning "ArgoCD CLI not found - manual sync will be required"
    fi
    
    # Check environment variables
    if [[ -z "${ARGOCD_SERVER:-}" ]]; then
        log_warning "ARGOCD_SERVER not set - will use default"
    fi
    
    log_success "Prerequisites check completed"
}

# Create namespaces
create_namespaces() {
    log_info "Creating namespaces..."
    
    local namespaces=("kube-green-system")
    
    case $ENVIRONMENT in
        staging)
            namespaces+=("staging")
            ;;
        production)
            namespaces+=("production")
            ;;
        development)
            namespaces+=("development")
            ;;
        all)
            namespaces+=("staging" "production" "development")
            ;;
    esac
    
    if [[ $SKIP_MONITORING == false ]]; then
        namespaces+=("monitoring")
    fi
    
    for ns in "${namespaces[@]}"; do
        if [[ $DRY_RUN == true ]]; then
            log_info "Would create namespace: $ns"
        else
            kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f -
            log_success "Namespace $ns created/updated"
        fi
    done
}

# Deploy kube-green operator
deploy_kube_green_operator() {
    log_info "Deploying kube-green operator..."
    
    if [[ $DRY_RUN == true ]]; then
        log_info "Would deploy kube-green operator"
        kubectl apply --dry-run=client -k "${PROJECT_ROOT}/apps/kube-green/base"
    else
        kubectl apply -k "${PROJECT_ROOT}/apps/kube-green/base"
        log_success "kube-green operator deployed"
        
        # Wait for operator to be ready
        log_info "Waiting for kube-green operator to be ready..."
        kubectl wait --for=condition=available deployment/kube-green-controller-manager \
            -n kube-green-system --timeout=300s
        log_success "kube-green operator is ready"
    fi
}

# Deploy environment-specific configurations
deploy_environment_config() {
    local env="$1"
    log_info "Deploying $env environment configuration..."
    
    local overlay_path="${PROJECT_ROOT}/apps/kube-green/overlays/$env"
    if [[ ! -d "$overlay_path" ]]; then
        log_warning "No overlay found for $env environment, skipping"
        return
    fi
    
    if [[ $DRY_RUN == true ]]; then
        log_info "Would deploy $env configuration"
        kubectl apply --dry-run=client -k "$overlay_path"
    else
        kubectl apply -k "$overlay_path"
        log_success "$env configuration deployed"
    fi
}

# Deploy Slack integration
deploy_slack_integration() {
    if [[ $SKIP_SLACK == true ]]; then
        log_info "Skipping Slack integration deployment"
        return
    fi
    
    log_info "Deploying Slack integration..."
    
    if [[ $DRY_RUN == true ]]; then
        log_info "Would deploy Slack integration"
        kubectl apply --dry-run=client -f "${PROJECT_ROOT}/apps/slack-integration/"
    else
        kubectl apply -f "${PROJECT_ROOT}/apps/slack-integration/"
        log_success "Slack integration deployed"
        
        # Wait for Slack service to be ready
        log_info "Waiting for Slack webhook service to be ready..."
        kubectl wait --for=condition=available deployment/slack-webhook-service \
            -n kube-green-system --timeout=300s
        log_success "Slack webhook service is ready"
    fi
}

# Deploy monitoring stack
deploy_monitoring() {
    if [[ $SKIP_MONITORING == true ]]; then
        log_info "Skipping monitoring stack deployment"
        return
    fi
    
    log_info "Deploying monitoring stack..."
    
    if [[ $DRY_RUN == true ]]; then
        log_info "Would deploy monitoring stack"
    else
        # Create monitoring namespace if it doesn't exist
        kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
        
        # Deploy Prometheus operator if not already installed
        if ! kubectl get crd prometheuses.monitoring.coreos.com &> /dev/null; then
            log_info "Installing Prometheus operator..."
            helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
            helm repo update
            helm upgrade --install prometheus-operator prometheus-community/kube-prometheus-stack \
                --namespace monitoring \
                --create-namespace \
                --wait
        fi
        
        # Deploy custom monitoring resources
        if [[ -d "${PROJECT_ROOT}/apps/monitoring" ]]; then
            kubectl apply -f "${PROJECT_ROOT}/apps/monitoring/"
        fi
        
        log_success "Monitoring stack deployed"
    fi
}

# Deploy ArgoCD applications
deploy_argocd_apps() {
    log_info "Deploying ArgoCD applications..."
    
    if [[ $DRY_RUN == true ]]; then
        log_info "Would deploy ArgoCD applications"
        kubectl apply --dry-run=client -f "${PROJECT_ROOT}/apps/argocd/"
    else
        kubectl apply -f "${PROJECT_ROOT}/apps/argocd/"
        log_success "ArgoCD applications deployed"
        
        # If ArgoCD CLI is available, sync applications
        if command -v argocd &> /dev/null && [[ -n "${ARGOCD_SERVER:-}" ]]; then
            log_info "Syncing ArgoCD applications..."
            argocd app sync k8s-resource-optimization-app-of-apps --server "$ARGOCD_SERVER"
            log_success "ArgoCD applications synced"
        else
            log_warning "ArgoCD CLI not available or server not configured - manual sync required"
        fi
    fi
}

# Validate deployment
validate_deployment() {
    log_info "Validating deployment..."
    
    # Check kube-green operator
    if kubectl get deployment kube-green-controller-manager -n kube-green-system &> /dev/null; then
        local replicas
        replicas=$(kubectl get deployment kube-green-controller-manager -n kube-green-system -o jsonpath='{.status.readyReplicas}')
        if [[ ${replicas:-0} -gt 0 ]]; then
            log_success "kube-green operator is running"
        else
            log_error "kube-green operator is not ready"
            return 1
        fi
    else
        log_error "kube-green operator not found"
        return 1
    fi
    
    # Check SleepInfo resources
    local sleepinfos
    sleepinfos=$(kubectl get sleepinfos --all-namespaces --no-headers 2>/dev/null | wc -l)
    if [[ $sleepinfos -gt 0 ]]; then
        log_success "Found $sleepinfos SleepInfo resources"
    else
        log_warning "No SleepInfo resources found"
    fi
    
    # Check Slack integration if not skipped
    if [[ $SKIP_SLACK == false ]]; then
        if kubectl get deployment slack-webhook-service -n kube-green-system &> /dev/null; then
            local slack_replicas
            slack_replicas=$(kubectl get deployment slack-webhook-service -n kube-green-system -o jsonpath='{.status.readyReplicas}')
            if [[ ${slack_replicas:-0} -gt 0 ]]; then
                log_success "Slack webhook service is running"
            else
                log_warning "Slack webhook service is not ready"
            fi
        else
            log_warning "Slack webhook service not found"
        fi
    fi
    
    log_success "Deployment validation completed"
}

# Send notification
send_notification() {
    local status="$1"
    local message="$2"
    
    if [[ -n "${SLACK_WEBHOOK_URL:-}" ]]; then
        local payload
        payload=$(jq -n \
            --arg text "$message" \
            --arg status "$status" \
            '{
                "text": $text,
                "attachments": [
                    {
                        "color": ($status == "success" | if . then "good" else "danger" end),
                        "fields": [
                            {
                                "title": "Environment",
                                "value": env.ENVIRONMENT,
                                "short": true
                            },
                            {
                                "title": "Timestamp",
                                "value": (now | strftime("%Y-%m-%d %H:%M:%S UTC")),
                                "short": true
                            }
                        ]
                    }
                ]
            }')
        
        curl -X POST -H 'Content-type: application/json' \
            --data "$payload" \
            "$SLACK_WEBHOOK_URL" || log_warning "Failed to send Slack notification"
    fi
}

# Main deployment function
main() {
    log_info "Starting Kubernetes Resource Optimization POC deployment"
    log_info "Environment: $ENVIRONMENT"
    log_info "Dry run: $DRY_RUN"
    log_info "Skip monitoring: $SKIP_MONITORING"
    log_info "Skip Slack: $SKIP_SLACK"
    
    # Step 1: Check prerequisites
    check_prerequisites
    
    # Step 2: Create namespaces
    create_namespaces
    
    # Step 3: Deploy kube-green operator
    deploy_kube_green_operator
    
    # Step 4: Deploy environment configurations
    case $ENVIRONMENT in
        all)
            for env in staging production development; do
                deploy_environment_config "$env"
            done
            ;;
        *)
            deploy_environment_config "$ENVIRONMENT"
            ;;
    esac
    
    # Step 5: Deploy Slack integration
    deploy_slack_integration
    
    # Step 6: Deploy monitoring stack
    deploy_monitoring
    
    # Step 7: Deploy ArgoCD applications
    deploy_argocd_apps
    
    # Step 8: Validate deployment
    if [[ $DRY_RUN == false ]]; then
        validate_deployment
    fi
    
    # Step 9: Send notification
    if [[ $DRY_RUN == false ]]; then
        send_notification "success" "Kubernetes Resource Optimization POC deployed successfully to $ENVIRONMENT"
    fi
    
    log_success "Deployment completed successfully!"
    
    # Print next steps
    cat << EOF

${GREEN}🎉 Deployment Complete!${NC}

Next steps:
1. Configure Slack webhooks and tokens in secrets
2. Update GitLab project ID and tokens
3. Configure ArgoCD notifications
4. Review and adjust sleep schedules
5. Set up monitoring dashboards

Resources deployed:
• kube-green operator in kube-green-system namespace
• SleepInfo configurations for $ENVIRONMENT
• Slack webhook service (if not skipped)
• Monitoring stack (if not skipped)
• ArgoCD applications

Documentation: ${PROJECT_ROOT}/docs/
Monitoring: kubectl port-forward -n monitoring svc/grafana 3000:80
Logs: kubectl logs -n kube-green-system deployment/kube-green-controller-manager

EOF
}

# Parse arguments and run main function
parse_args "$@"
main
