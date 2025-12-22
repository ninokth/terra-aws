#!/bin/bash
#
# Test Infrastructure Script
#
# Tests deployed infrastructure connectivity:
# 1. Test SSH access to bastion
# 2. Test SSH access to private host (via ProxyJump)
# 3. Test NAT connectivity (internet from private host)
#
# Usage:
#   ./scripts/test_infrastructure.sh
#
# Prerequisites:
#   Run ./scripts/deploy.sh first
#

set -e

# ==============================================================================
# Setup
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# Initialize logging
init_logging "test_infrastructure"

# Track test results
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# ==============================================================================
# Test Result Tracking
# ==============================================================================

record_pass() {
    local test_name="$1"
    print_result "$test_name" "pass"
    ((TESTS_PASSED++))
}

record_fail() {
    local test_name="$1"
    print_result "$test_name" "fail"
    ((TESTS_FAILED++))
}

record_skip() {
    local test_name="$1"
    print_result "$test_name" "skip"
    ((TESTS_SKIPPED++))
}

# ==============================================================================
# Prerequisite Check
# ==============================================================================

check_deployment() {
    log_step "Checking Deployment Status"

    # Check if infrastructure is deployed
    if ! check_terraform_deployed; then
        log_error "Infrastructure not deployed"
        log_error "Run: ./scripts/deploy.sh"
        return 1
    fi

    local bastion_ip=$(get_bastion_public_ip)
    local private_ip=$(get_private_instance_ip)

    log_info "Bastion Public IP:  $bastion_ip"
    log_info "Private Host IP:    $private_ip"

    # Save to state for other functions
    save_state "bastion_ip" "$bastion_ip"
    save_state "private_ip" "$private_ip"

    record_pass "Infrastructure deployed"
    return 0
}

# ==============================================================================
# Test SSH to Bastion
# ==============================================================================

test_ssh_bastion() {
    log_step "Testing SSH Access to Bastion"

    local bastion_ip=$(load_state "bastion_ip")

    if [[ -z "$bastion_ip" ]]; then
        record_fail "SSH to bastion (no IP)"
        return 1
    fi

    log_info "Connecting to: $bastion_ip"

    # Test SSH and get hostname
    local result
    if result=$(ssh $SSH_OPTS -i "$SSH_KEY_PATH" "${SSH_USER}@${bastion_ip}" "hostname && uname -r" 2>&1); then
        local hostname=$(echo "$result" | head -1)
        local kernel=$(echo "$result" | tail -1)
        log_info "  Hostname: $hostname"
        log_info "  Kernel:   $kernel"
        record_pass "SSH to bastion"
        return 0
    else
        log_error "SSH connection failed: $result"
        record_fail "SSH to bastion"
        return 1
    fi
}

# ==============================================================================
# Test Ping to Bastion
# ==============================================================================

test_bastion_connectivity() {
    log_step "Testing Bastion Internet Connectivity"

    local bastion_ip=$(load_state "bastion_ip")

    if [[ -z "$bastion_ip" ]]; then
        record_fail "Bastion connectivity (no IP)"
        return 1
    fi

    log_info "Running ping from bastion to 8.8.8.8 (Google DNS)..."
    echo ""

    # SSH to bastion and run ping there, capture output
    local ping_output
    ping_output=$(ssh $SSH_OPTS -i "$SSH_KEY_PATH" "${SSH_USER}@${bastion_ip}" "ping -c 3 -W 5 8.8.8.8" 2>&1) || true

    if echo "$ping_output" | grep -q "bytes from"; then
        echo "$ping_output" | while IFS= read -r line; do
            log_info "  $line"
        done
        echo ""
        record_pass "Bastion ping to 8.8.8.8"
        return 0
    else
        echo "$ping_output" | while IFS= read -r line; do
            log_error "  $line"
        done
        echo ""
        record_fail "Bastion ping to 8.8.8.8"
        return 1
    fi
}

# ==============================================================================
# Test SSH to Private Host
# ==============================================================================

test_ssh_private() {
    log_step "Testing SSH Access to Private Host"

    local bastion_ip=$(load_state "bastion_ip")
    local private_ip=$(load_state "private_ip")

    if [[ -z "$bastion_ip" ]] || [[ -z "$private_ip" ]]; then
        record_fail "SSH to private (no IP)"
        return 1
    fi

    log_info "Connecting via: $bastion_ip -> $private_ip"

    # Build ProxyCommand
    local proxy_cmd="ssh -W %h:%p $SSH_OPTS -i $SSH_KEY_PATH ${SSH_USER}@${bastion_ip}"

    # Test SSH via ProxyJump
    local result
    if result=$(ssh $SSH_OPTS -i "$SSH_KEY_PATH" -o "ProxyCommand=$proxy_cmd" "${SSH_USER}@${private_ip}" "hostname && uname -r" 2>&1); then
        local hostname=$(echo "$result" | head -1)
        local kernel=$(echo "$result" | tail -1)
        log_info "  Hostname: $hostname"
        log_info "  Kernel:   $kernel"
        record_pass "SSH to private host"
        return 0
    else
        log_error "SSH connection failed: $result"
        record_fail "SSH to private host"
        return 1
    fi
}

# ==============================================================================
# Test NAT Connectivity
# ==============================================================================

test_nat_connectivity() {
    log_step "Testing NAT Internet Connectivity"

    local bastion_ip=$(load_state "bastion_ip")
    local private_ip=$(load_state "private_ip")

    if [[ -z "$bastion_ip" ]] || [[ -z "$private_ip" ]]; then
        record_fail "NAT test (no IP)"
        return 1
    fi

    log_info "Testing internet access from private host ($private_ip via $bastion_ip)..."
    echo ""

    # Build ProxyCommand
    local proxy_cmd="ssh -W %h:%p $SSH_OPTS -i $SSH_KEY_PATH ${SSH_USER}@${bastion_ip}"

    # Test 1: Ping from private host to external IP (Google DNS)
    log_info "Test 1: Ping from private host to 8.8.8.8 (Google DNS)"
    local ping_result
    ping_result=$(ssh $SSH_OPTS -i "$SSH_KEY_PATH" -o "ProxyCommand=$proxy_cmd" "${SSH_USER}@${private_ip}" "ping -c 3 -W 5 8.8.8.8" 2>&1) || true

    if echo "$ping_result" | grep -q "bytes from"; then
        echo "$ping_result" | while IFS= read -r line; do
            log_info "    $line"
        done
        echo ""
        record_pass "NAT ping to 8.8.8.8"
    else
        echo "$ping_result" | while IFS= read -r line; do
            log_error "    $line"
        done
        echo ""
        record_fail "NAT ping to 8.8.8.8"
    fi

    # Test 2: DNS resolution from private host
    log_info "Test 2: DNS resolution from private host"
    local dns_result
    dns_result=$(ssh $SSH_OPTS -i "$SSH_KEY_PATH" -o "ProxyCommand=$proxy_cmd" "${SSH_USER}@${private_ip}" "nslookup google.com 2>&1 | head -6" 2>&1) || true

    if echo "$dns_result" | grep -q "Address:"; then
        echo "$dns_result" | while IFS= read -r line; do
            log_info "    $line"
        done
        echo ""
        record_pass "NAT DNS resolution"
    else
        echo "$dns_result" | while IFS= read -r line; do
            log_error "    $line"
        done
        echo ""
        record_fail "NAT DNS resolution"
    fi

    # Test 3: HTTP request with verbose output
    log_info "Test 3: HTTP request to api.ipify.org (get external IP)"
    local curl_result
    curl_result=$(ssh $SSH_OPTS -i "$SSH_KEY_PATH" -o "ProxyCommand=$proxy_cmd" "${SSH_USER}@${private_ip}" "curl -4 -v --max-time 15 https://api.ipify.org 2>&1" 2>&1) || true

    if echo "$curl_result" | grep -q "HTTP.*200\|[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+"; then
        # Show key lines from verbose curl output
        echo "$curl_result" | grep -E "^\*|^< |^> |^[0-9]" | head -20 | while IFS= read -r line; do
            log_info "    $line"
        done

        # Extract exit IP (last line should be the IP)
        local exit_ip=$(echo "$curl_result" | tail -1 | tr -d '[:space:]')
        echo ""
        log_info "  External IP seen: $exit_ip"
        log_info "  Bastion EIP:      $bastion_ip"

        if [[ "$exit_ip" == "$bastion_ip" ]]; then
            log_success "  Traffic correctly exits through bastion EIP"
            record_pass "NAT HTTP request (via bastion)"
        else
            log_warning "  Exit IP does not match bastion EIP (may be using different gateway)"
            record_pass "NAT HTTP request (different exit IP)"
        fi
        echo ""
    else
        echo "$curl_result" | while IFS= read -r line; do
            log_error "    $line"
        done
        echo ""
        record_fail "NAT HTTP request"
    fi
}

# ==============================================================================
# Print Summary
# ==============================================================================

print_test_summary() {
    echo ""
    print_separator
    echo "  TEST SUMMARY"
    print_separator
    echo ""
    echo "  Passed:  $TESTS_PASSED"
    echo "  Failed:  $TESTS_FAILED"
    echo "  Skipped: $TESTS_SKIPPED"
    echo ""

    if [[ $TESTS_FAILED -eq 0 ]]; then
        log_success "All tests passed!"
        echo ""
        echo "Next steps:"
        echo ""
        echo "  1. Connect to hosts:"
        echo "     ./scripts/connect_bastion.sh    # SSH to bastion with agent forwarding"
        echo "     ./scripts/connect_private.sh    # SSH to private host via ProxyJump"
        echo ""
        echo "  2. (Optional) Generate config files for integration:"
        echo "     ./scripts/generate_config.sh"
        echo ""
        echo "     Creates config files with infrastructure details:"
        echo "       - config/infrastructure.json  JSON for scripts/automation"
        echo "       - config/infrastructure.env   Shell vars: source config/infrastructure.env"
        echo "       - config/ssh_config           SSH config: ssh -F config/ssh_config bastion"
        echo ""
        echo "  3. When done, destroy:"
        echo "     ./scripts/destroy.sh"
    else
        log_error "Some tests failed"
        echo ""
        echo "Troubleshooting:"
        echo "  - Check logs: cat \$(ls -t logs/test_*.log | head -1)"
        echo "  - Verify AWS credentials: aws sts get-caller-identity"
        echo "  - Check instance status in AWS console"
    fi

    print_separator
}

# ==============================================================================
# Main
# ==============================================================================

main() {
    echo ""
    print_separator
    echo "  Terraform Bastion Infrastructure - Test Suite"
    print_separator
    echo ""

    # Check deployment status
    check_deployment || { print_test_summary; finalize_logging; exit 1; }

    # Run tests
    test_ssh_bastion
    test_bastion_connectivity
    test_ssh_private
    test_nat_connectivity

    # Print summary
    print_test_summary
    finalize_logging

    # Exit with failure count
    exit $TESTS_FAILED
}

main "$@"
