#!/bin/bash
#
# Destroy Infrastructure Script
#
# Destroys all Terraform infrastructure and verifies complete cleanup.
#
# Usage:
#   ./scripts/destroy.sh
#
# Prerequisites:
#   Infrastructure must be deployed (./scripts/deploy.sh)
#

set -e

# ==============================================================================
# Setup
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# Initialize logging
init_logging "destroy"

# ==============================================================================
# Destroy Infrastructure
# ==============================================================================

destroy_infrastructure() {
    log_step "Destroying Infrastructure"

    log_info "Running: terraform destroy -auto-approve"
    echo ""

    if run_terraform destroy -auto-approve; then
        save_state "infrastructure_deployed" "false"
        save_state "nat_ready" "false"
        echo ""
        log_success "Infrastructure destroyed"
        return 0
    else
        log_error "Infrastructure destruction failed"
        return 1
    fi
}

# ==============================================================================
# Verify Cleanup
# ==============================================================================

verify_cleanup() {
    log_step "Verifying Complete Cleanup"

    local failed=0

    # Check Terraform state is empty
    log_info "Checking Terraform state..."
    local state_output=$(run_terraform show 2>&1)
    if [[ "$state_output" == *"empty"* ]] || [[ -z "$state_output" ]]; then
        log_info "  Terraform state is empty"
    else
        log_warning "  Terraform state is not empty"
        failed=1
    fi

    # Check for remaining EIPs
    log_info "Checking for remaining Elastic IPs..."
    local eips=$(aws ec2 describe-addresses --filters "Name=tag:Name,Values=${NAME_PREFIX}*" --query 'Addresses[*].PublicIp' --output text 2>/dev/null)
    if [[ -z "$eips" ]]; then
        log_info "  No remaining EIPs"
    else
        log_warning "  Found EIPs: $eips"
        failed=1
    fi

    # Check for remaining EC2 instances
    log_info "Checking for remaining EC2 instances..."
    local instances=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=${NAME_PREFIX}*" "Name=instance-state-name,Values=running,pending,stopping,stopped" --query 'Reservations[*].Instances[*].InstanceId' --output text 2>/dev/null)
    if [[ -z "$instances" ]]; then
        log_info "  No remaining EC2 instances"
    else
        log_warning "  Found instances: $instances"
        failed=1
    fi

    # Check for remaining VPCs
    log_info "Checking for remaining VPCs..."
    local vpcs=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=${NAME_PREFIX}*" --query 'Vpcs[*].VpcId' --output text 2>/dev/null)
    if [[ -z "$vpcs" ]]; then
        log_info "  No remaining VPCs"
    else
        log_warning "  Found VPCs: $vpcs"
        failed=1
    fi

    # Check for remaining key pairs
    log_info "Checking for remaining key pairs..."
    local keys=$(aws ec2 describe-key-pairs --filters "Name=key-name,Values=${NAME_PREFIX}*" --query 'KeyPairs[*].KeyName' --output text 2>/dev/null)
    if [[ -z "$keys" ]]; then
        log_info "  No remaining key pairs"
    else
        log_warning "  Found key pairs: $keys"
        failed=1
    fi

    if [[ $failed -eq 0 ]]; then
        log_success "All resources destroyed - Zero cost confirmed"
        save_state "cleanup_verified" "true"
        return 0
    else
        log_error "Resource cleanup incomplete - manual cleanup may be required"
        save_state "cleanup_verified" "false"
        return 1
    fi
}

# ==============================================================================
# Summary
# ==============================================================================

print_summary() {
    echo ""
    print_separator
    log_success "Destruction Complete!"
    print_separator
    echo ""
    echo "Status:"
    echo "  Infrastructure:   Destroyed"
    echo "  Cleanup Verified: $(load_state 'cleanup_verified' 'unknown')"
    echo ""
    echo "To redeploy:"
    echo "  ./scripts/deploy.sh"
    echo ""
    print_separator
}

# ==============================================================================
# Main
# ==============================================================================

main() {
    echo ""
    print_separator
    echo "  Terraform Bastion Infrastructure - Destroy"
    print_separator
    echo ""

    # Check if there's anything to destroy
    if ! check_terraform_deployed; then
        log_warning "No infrastructure detected"
        log_info "Nothing to destroy"
        exit 0
    fi

    local bastion_ip=$(get_bastion_public_ip)
    log_info "Current Bastion IP: $bastion_ip"
    echo ""

    # Destroy
    destroy_infrastructure || exit 1

    # Verify cleanup
    verify_cleanup

    print_summary
    finalize_logging
}

main "$@"
