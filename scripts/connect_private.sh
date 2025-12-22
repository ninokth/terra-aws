#!/bin/bash
#
# Connect to private host (prv_host-01) using SSH ProxyJump through bastion
# This allows direct connection from your workstation without manually hopping through bastion
#
# Usage:
#   ./scripts/connect_private.sh
#
# Configuration is read from config/user.conf
#

set -e

# ==============================================================================
# Load Common Library
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# ==============================================================================
# Main Script
# ==============================================================================

# Check if infrastructure is deployed
if ! check_terraform_deployed; then
    log_error "Could not retrieve IPs from Terraform outputs"
    log_info "Make sure infrastructure is deployed: terraform -chdir=providers apply"
    exit 1
fi

# Get IPs
BASTION_IP=$(get_bastion_public_ip)
PRIVATE_IP=$(get_private_instance_ip)

if [[ -z "$BASTION_IP" ]] || [[ -z "$PRIVATE_IP" ]]; then
    log_error "Could not retrieve IPs from Terraform outputs"
    log_info "Make sure infrastructure is deployed: terraform -chdir=providers apply"
    exit 1
fi

# Check SSH key exists
if ! check_ssh_key; then
    log_error "SSH key not found at $SSH_KEY_PATH"
    log_info "Run ./scripts/setup_ssh_key.sh first"
    log_info "Or update SSH_KEY_PATH in config/user.conf"
    exit 1
fi

# Display connection info
echo ""
log_info "Connecting to private host (prv_host-01) via ProxyJump..."
echo "  Bastion IP: $BASTION_IP"
echo "  Private IP: $PRIVATE_IP"
echo "  User: $SSH_USER"
echo "  Key: $SSH_KEY_PATH"
echo ""
log_info "Connection path: workstation -> bastion -> private host"
echo ""

# Connect using ProxyJump (-J flag)
ssh -J "${SSH_USER}@${BASTION_IP}" \
    -i "$SSH_KEY_PATH" \
    -o StrictHostKeyChecking=accept-new \
    -o UserKnownHostsFile=/dev/null \
    -o LogLevel=ERROR \
    "${SSH_USER}@${PRIVATE_IP}"
