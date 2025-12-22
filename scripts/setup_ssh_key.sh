#!/bin/bash
#
# Generate Ed25519 SSH key for AWS instances
# This script ensures SSH key exists before Terraform runs
#
# Usage:
#   ./scripts/setup_ssh_key.sh
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

echo ""
log_info "SSH Key Setup"
echo "=============="
echo ""

SSH_PUB_KEY_PATH="${SSH_KEY_PATH}.pub"

log_info "Checking for ${SSH_KEY_TYPE} SSH key..."
echo "  Key path: $SSH_KEY_PATH"
echo ""

if [[ -f "$SSH_KEY_PATH" ]]; then
    log_success "SSH key already exists: $SSH_KEY_PATH"
    log_success "Public key: $SSH_PUB_KEY_PATH"

    # Show key info
    echo ""
    log_info "Key information:"
    ssh-keygen -l -f "$SSH_PUB_KEY_PATH"
else
    log_warning "SSH key not found. Generating ${SSH_KEY_TYPE} key pair..."

    # Create .ssh directory if needed
    mkdir -p "$(dirname "$SSH_KEY_PATH")"
    chmod 700 "$(dirname "$SSH_KEY_PATH")"

    # Generate key
    ssh-keygen -t "$SSH_KEY_TYPE" -f "$SSH_KEY_PATH" -N "" -C "${NAME_PREFIX}-bastion"

    if [[ $? -eq 0 ]]; then
        chmod 600 "$SSH_KEY_PATH"
        chmod 644 "$SSH_PUB_KEY_PATH"
        log_success "Generated new ${SSH_KEY_TYPE} SSH key pair"
        echo "  Private key: $SSH_KEY_PATH"
        echo "  Public key: $SSH_PUB_KEY_PATH"
    else
        log_error "Failed to generate SSH keys"
        exit 1
    fi
fi

# Display public key for verification
echo ""
log_info "Public key contents:"
cat "$SSH_PUB_KEY_PATH"
echo ""
log_success "Key ready for AWS deployment"
echo ""
