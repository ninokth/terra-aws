#!/bin/bash
#
# Connect to bastion host (pub_host-01) with SSH agent forwarding enabled
# This allows you to use your local SSH key to connect to the private host from the bastion
#
# Usage:
#   ./scripts/connect_bastion.sh
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
    log_error "Could not retrieve bastion IP from Terraform outputs"
    log_info "Make sure infrastructure is deployed: terraform -chdir=providers apply"
    exit 1
fi

# Get bastion IP
BASTION_IP=$(get_bastion_public_ip)

# Check SSH key exists
if ! check_ssh_key; then
    log_error "SSH key not found at $SSH_KEY_PATH"
    log_info "Run ./scripts/setup_ssh_key.sh first"
    log_info "Or update SSH_KEY_PATH in config/user.conf"
    exit 1
fi

# Display connection info
echo ""
log_info "Connecting to bastion host (pub_host-01)..."
echo "  IP: $BASTION_IP"
echo "  User: $SSH_USER"
echo "  Key: $SSH_KEY_PATH"
echo "  SSH agent forwarding: ENABLED"
echo ""
log_info "From bastion, you can connect to private host:"
echo "  ssh ${SSH_USER}@$(get_private_instance_ip)"
echo ""

# Connect with agent forwarding enabled (-A flag)
ssh -A \
    -i "$SSH_KEY_PATH" \
    -o StrictHostKeyChecking=accept-new \
    -o UserKnownHostsFile=/dev/null \
    -o LogLevel=ERROR \
    "${SSH_USER}@${BASTION_IP}"
