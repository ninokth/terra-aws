#!/bin/bash
#
# Remove Ed25519 SSH key pair
# Use this script to clean up SSH keys after destroying infrastructure
#
# Usage:
#   ./scripts/cleanup_ssh_key.sh
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

SSH_PUB_KEY_PATH="${SSH_KEY_PATH}.pub"

echo ""
log_info "SSH Key Cleanup Script"
echo "======================="
echo ""

# Check if keys exist
if [[ ! -f "$SSH_KEY_PATH" ]] && [[ ! -f "$SSH_PUB_KEY_PATH" ]]; then
    log_success "No SSH keys found at $SSH_KEY_PATH"
    log_info "Already clean."
    exit 0
fi

# Show what will be deleted
log_warning "This will delete the following files:"
[[ -f "$SSH_KEY_PATH" ]] && echo "  - $SSH_KEY_PATH (private key)"
[[ -f "$SSH_PUB_KEY_PATH" ]] && echo "  - $SSH_PUB_KEY_PATH (public key)"
echo ""

# Ask for confirmation
if ! confirm "Are you sure you want to delete these keys?" "n"; then
    log_info "Aborted. No keys were deleted."
    exit 1
fi

# Remove keys
REMOVED=0
if [[ -f "$SSH_KEY_PATH" ]]; then
    rm -f "$SSH_KEY_PATH"
    log_success "Removed private key: $SSH_KEY_PATH"
    REMOVED=1
fi

if [[ -f "$SSH_PUB_KEY_PATH" ]]; then
    rm -f "$SSH_PUB_KEY_PATH"
    log_success "Removed public key: $SSH_PUB_KEY_PATH"
    REMOVED=1
fi

if [[ $REMOVED -eq 1 ]]; then
    echo ""
    log_success "SSH keys cleaned up successfully"
else
    log_info "No keys to remove"
fi
echo ""
