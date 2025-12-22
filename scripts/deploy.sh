#!/bin/bash
#
# Deploy Infrastructure Script
#
# Deploys the Terraform infrastructure and waits for instances to be ready.
#
# Usage:
#   ./scripts/deploy.sh
#
# Prerequisites:
#   Run ./scripts/first_time_setup.sh first
#

set -e

# ==============================================================================
# Setup
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# Initialize logging
init_logging "deploy"

# ==============================================================================
# Prerequisite Check
# ==============================================================================

check_setup() {
    log_step "Checking Prerequisites"

    # Check if first_time_setup was run
    if ! state_exists "setup_completed"; then
        log_error "First time setup not completed"
        log_error "Run: ./scripts/first_time_setup.sh"
        return 1
    fi

    # Check terraform initialized
    if ! state_exists "terraform_initialized"; then
        log_error "Terraform not initialized"
        log_error "Run: ./scripts/first_time_setup.sh"
        return 1
    fi

    # Check SSH key
    if ! check_ssh_key "$SSH_KEY_PATH"; then
        log_error "SSH key not found: $SSH_KEY_PATH"
        return 1
    fi

    log_success "Prerequisites validated"
    return 0
}

# ==============================================================================
# Deploy Infrastructure
# ==============================================================================

deploy_infrastructure() {
    log_step "Deploying Infrastructure"

    log_info "Running: terraform apply -auto-approve"
    echo ""

    if run_terraform apply -auto-approve; then
        # Get and save IPs
        local bastion_ip=$(get_bastion_public_ip)
        local private_ip=$(get_private_instance_ip)

        save_state "bastion_ip" "$bastion_ip"
        save_state "private_ip" "$private_ip"
        save_state "infrastructure_deployed" "true"
        save_state "deploy_time" "$(date -u +"%Y-%m-%d %H:%M:%S UTC")"

        echo ""
        log_success "Infrastructure deployed"
        log_info "Bastion Public IP:  $bastion_ip"
        log_info "Private Host IP:    $private_ip"
        return 0
    else
        log_error "Infrastructure deployment failed"
        return 1
    fi
}

# ==============================================================================
# Wait for Instances
# ==============================================================================

wait_for_bastion() {
    log_step "Waiting for Bastion to be Ready"

    local bastion_ip=$(load_state "bastion_ip")
    local max_attempts=30
    local attempt=1

    log_info "Waiting for SSH on $bastion_ip..."

    while [[ $attempt -le $max_attempts ]]; do
        if ssh $SSH_OPTS -i "$SSH_KEY_PATH" "${SSH_USER}@${bastion_ip}" "echo ready" &>/dev/null; then
            log_success "Bastion is ready"
            return 0
        fi
        echo -n "."
        sleep 10
        ((attempt++))
    done

    echo ""
    log_error "Bastion did not become ready in time"
    return 1
}

wait_for_private() {
    log_step "Waiting for Private Host to be Ready"

    local bastion_ip=$(load_state "bastion_ip")
    local private_ip=$(load_state "private_ip")
    local max_attempts=30
    local attempt=1

    log_info "Waiting for SSH on $private_ip (via bastion)..."

    local proxy_cmd="ssh -W %h:%p $SSH_OPTS -i $SSH_KEY_PATH ${SSH_USER}@${bastion_ip}"

    while [[ $attempt -le $max_attempts ]]; do
        if ssh $SSH_OPTS -i "$SSH_KEY_PATH" -o "ProxyCommand=$proxy_cmd" "${SSH_USER}@${private_ip}" "echo ready" &>/dev/null; then
            log_success "Private host is ready"
            return 0
        fi
        echo -n "."
        sleep 10
        ((attempt++))
    done

    echo ""
    log_error "Private host did not become ready in time"
    return 1
}

wait_for_nat() {
    log_step "Waiting for NAT to be Ready"

    local bastion_ip=$(load_state "bastion_ip")
    local private_ip=$(load_state "private_ip")
    local max_attempts=18  # 3 minutes total
    local attempt=1

    log_info "Waiting for nftables NAT setup on bastion..."

    local proxy_cmd="ssh -W %h:%p $SSH_OPTS -i $SSH_KEY_PATH ${SSH_USER}@${bastion_ip}"

    while [[ $attempt -le $max_attempts ]]; do
        if ssh $SSH_OPTS -i "$SSH_KEY_PATH" -o "ProxyCommand=$proxy_cmd" "${SSH_USER}@${private_ip}" "curl -4 -s --max-time 5 https://api.ipify.org" &>/dev/null; then
            log_success "NAT is ready"
            save_state "nat_ready" "true"
            return 0
        fi
        echo -n "."
        sleep 10
        ((attempt++))
    done

    echo ""
    log_warning "NAT did not become ready in time (may still be configuring)"
    save_state "nat_ready" "false"
    return 0  # Don't fail, just warn
}

# ==============================================================================
# Summary
# ==============================================================================

print_summary() {
    local bastion_ip=$(load_state "bastion_ip")
    local private_ip=$(load_state "private_ip")

    echo ""
    print_separator
    log_success "Deployment Complete!"
    print_separator
    echo ""
    echo "Infrastructure:"
    echo "  Bastion Public IP:  $bastion_ip"
    echo "  Private Host IP:    $private_ip"
    echo "  NAT Ready:          $(load_state 'nat_ready' 'unknown')"
    echo ""
    echo "Next steps:"
    echo ""
    echo "  1. Test infrastructure:"
    echo "     ./scripts/test_infrastructure.sh"
    echo ""
    echo "  2. Generate connection configs:"
    echo "     ./scripts/generate_config.sh"
    echo ""
    echo "  3. Connect:"
    echo "     ./scripts/connect_bastion.sh"
    echo "     ./scripts/connect_private.sh"
    echo ""
    echo "  4. When done, destroy:"
    echo "     ./scripts/destroy.sh"
    echo ""
    print_separator
}

# ==============================================================================
# Main
# ==============================================================================

main() {
    echo ""
    print_separator
    echo "  Terraform Bastion Infrastructure - Deploy"
    print_separator
    echo ""

    # Check prerequisites
    check_setup || exit 1

    # Check if already deployed
    if check_terraform_deployed; then
        log_warning "Infrastructure already deployed"
        local bastion_ip=$(get_bastion_public_ip)
        log_info "Bastion IP: $bastion_ip"
        log_info "To redeploy, destroy first: ./scripts/destroy.sh"
        exit 0
    fi

    # Deploy
    deploy_infrastructure || exit 1

    # Wait for readiness
    wait_for_bastion || exit 1
    wait_for_private || exit 1
    wait_for_nat

    print_summary
    finalize_logging
}

main "$@"
