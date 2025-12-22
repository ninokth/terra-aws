#!/bin/bash
#
# Generate infrastructure configuration files after Terraform deployment
# This creates config files with dynamic connection details
#
# Usage:
#   ./scripts/generate_config.sh
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
log_info "Infrastructure Configuration Generator"
echo "========================================"
echo ""

# Check if Terraform state exists
if [[ ! -f "$TERRAFORM_DIR/terraform.tfstate" ]]; then
    log_error "No Terraform state found"
    log_info "Deploy infrastructure first: terraform -chdir=providers apply"
    exit 1
fi

# Check if infrastructure is deployed
if ! check_terraform_deployed; then
    log_error "Infrastructure not deployed"
    log_info "Deploy infrastructure first: terraform -chdir=providers apply"
    exit 1
fi

log_info "Fetching infrastructure details from Terraform..."

# Get all outputs
BASTION_PUBLIC_IP=$(get_bastion_public_ip)
BASTION_PRIVATE_IP=$(get_bastion_private_ip)
PRIVATE_IP=$(get_private_instance_ip)
VPC_ID=$(get_terraform_output "vpc_id")

# Get timestamp
TIMESTAMP=$(date -u "+%Y-%m-%d %H:%M:%S UTC")

echo ""
log_info "Infrastructure Details:"
echo "  Bastion Public IP:  $BASTION_PUBLIC_IP"
echo "  Bastion Private IP: $BASTION_PRIVATE_IP"
echo "  Private Host IP:    $PRIVATE_IP"
echo "  VPC ID:             $VPC_ID"
echo "  Region:             $AWS_REGION"
echo ""

# Create config directory
CONFIG_DIR="$PROJECT_ROOT/config"
mkdir -p "$CONFIG_DIR"

# ==============================================================================
# Generate JSON Config
# ==============================================================================

JSON_FILE="$CONFIG_DIR/infrastructure.json"
cat > "$JSON_FILE" <<EOF
{
  "generated_at": "$TIMESTAMP",
  "region": "$AWS_REGION",
  "vpc_id": "$VPC_ID",
  "bastion": {
    "public_ip": "$BASTION_PUBLIC_IP",
    "private_ip": "$BASTION_PRIVATE_IP",
    "ssh_user": "$SSH_USER",
    "ssh_key": "$SSH_KEY_PATH",
    "hostname": "pub_host-01"
  },
  "private_host": {
    "private_ip": "$PRIVATE_IP",
    "ssh_user": "$SSH_USER",
    "ssh_key": "$SSH_KEY_PATH",
    "hostname": "prv_host-01"
  },
  "connection": {
    "bastion_command": "ssh -A -i $SSH_KEY_PATH $SSH_USER@$BASTION_PUBLIC_IP",
    "private_command": "ssh -J $SSH_USER@$BASTION_PUBLIC_IP -i $SSH_KEY_PATH $SSH_USER@$PRIVATE_IP"
  }
}
EOF

log_success "Generated JSON config: config/infrastructure.json"

# ==============================================================================
# Generate INI Config
# ==============================================================================

INI_FILE="$CONFIG_DIR/infrastructure.ini"
cat > "$INI_FILE" <<EOF
# Infrastructure Configuration
# Generated: $TIMESTAMP

[metadata]
generated_at = $TIMESTAMP
region = $AWS_REGION
vpc_id = $VPC_ID

[bastion]
public_ip = $BASTION_PUBLIC_IP
private_ip = $BASTION_PRIVATE_IP
ssh_user = $SSH_USER
ssh_key = $SSH_KEY_PATH
hostname = pub_host-01

[private_host]
private_ip = $PRIVATE_IP
ssh_user = $SSH_USER
ssh_key = $SSH_KEY_PATH
hostname = prv_host-01

[connection]
bastion_command = ssh -A -i $SSH_KEY_PATH $SSH_USER@$BASTION_PUBLIC_IP
private_command = ssh -J $SSH_USER@$BASTION_PUBLIC_IP -i $SSH_KEY_PATH $SSH_USER@$PRIVATE_IP
EOF

log_success "Generated INI config: config/infrastructure.ini"

# ==============================================================================
# Generate Shell Environment File
# ==============================================================================

ENV_FILE="$CONFIG_DIR/infrastructure.env"
cat > "$ENV_FILE" <<EOF
# Infrastructure Environment Variables
# Generated: $TIMESTAMP
# Source this file: source config/infrastructure.env

export BASTION_PUBLIC_IP="$BASTION_PUBLIC_IP"
export BASTION_PRIVATE_IP="$BASTION_PRIVATE_IP"
export PRIVATE_HOST_IP="$PRIVATE_IP"
export VPC_ID="$VPC_ID"
export AWS_REGION="$AWS_REGION"
export SSH_USER="$SSH_USER"
export SSH_KEY_PATH="$SSH_KEY_PATH"

# Convenience aliases
alias ssh-bastion="ssh -A -i \$SSH_KEY_PATH \$SSH_USER@\$BASTION_PUBLIC_IP"
alias ssh-private="ssh -J \$SSH_USER@\$BASTION_PUBLIC_IP -i \$SSH_KEY_PATH \$SSH_USER@\$PRIVATE_HOST_IP"
EOF

log_success "Generated ENV file: config/infrastructure.env"

# ==============================================================================
# Generate SSH Config Snippet
# ==============================================================================

SSH_CONFIG_FILE="$CONFIG_DIR/ssh_config"
cat > "$SSH_CONFIG_FILE" <<EOF
# SSH Config Snippet for Infrastructure
# Generated: $TIMESTAMP
#
# To use this config, either:
#   1. Append to ~/.ssh/config:  cat config/ssh_config >> ~/.ssh/config
#   2. Use with -F flag:         ssh -F config/ssh_config bastion

Host bastion ${NAME_PREFIX}-bastion pub_host-01
    HostName $BASTION_PUBLIC_IP
    User $SSH_USER
    IdentityFile $SSH_KEY_PATH
    ForwardAgent yes
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null

Host private ${NAME_PREFIX}-private prv_host-01
    HostName $PRIVATE_IP
    User $SSH_USER
    IdentityFile $SSH_KEY_PATH
    ProxyJump bastion
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
EOF

log_success "Generated SSH config: config/ssh_config"

# ==============================================================================
# Generate README for Config Directory
# ==============================================================================

README_FILE="$CONFIG_DIR/README.md"
cat > "$README_FILE" <<EOF
# Infrastructure Configuration Files

Generated: **$TIMESTAMP**

## Available Formats

- **infrastructure.json** - JSON format with all infrastructure details
- **infrastructure.ini** - INI format for easy parsing
- **infrastructure.env** - Shell environment variables (source this file)
- **ssh_config** - SSH configuration snippet
- **user.conf** - User configuration (if exists)
- **README.md** - This file

## Quick Start

### Using Environment Variables

\`\`\`bash
# Source the environment file
source config/infrastructure.env

# Use the aliases
ssh-bastion    # Connect to bastion
ssh-private    # Connect to private host via ProxyJump
\`\`\`

### Using SSH Config

\`\`\`bash
# Connect using SSH config
ssh -F config/ssh_config bastion
ssh -F config/ssh_config private

# Or append to your ~/.ssh/config:
cat config/ssh_config >> ~/.ssh/config
ssh bastion
ssh private
\`\`\`

### Using Connection Scripts

\`\`\`bash
# Scripts automatically read from terraform outputs and config/user.conf
./scripts/connect_bastion.sh
./scripts/connect_private.sh
\`\`\`

## Current Infrastructure

### Bastion Host
- **Public IP**: $BASTION_PUBLIC_IP
- **Private IP**: $BASTION_PRIVATE_IP
- **Hostname**: pub_host-01

### Private Host
- **Private IP**: $PRIVATE_IP
- **Hostname**: prv_host-01

### VPC
- **VPC ID**: $VPC_ID
- **Region**: $AWS_REGION

## Regenerating Configuration

If you destroy and recreate the infrastructure, regenerate these files:

\`\`\`bash
./scripts/generate_config.sh
\`\`\`

This will update all configuration files with new IP addresses.
EOF

log_success "Generated README: config/README.md"

# ==============================================================================
# Summary
# ==============================================================================

echo ""
echo "========================================"
log_success "Configuration generation complete!"
echo ""
echo "Configuration files created in: config/"
echo ""
echo "Quick commands:"
echo "  Source env:    source config/infrastructure.env"
echo "  SSH bastion:   ssh -F config/ssh_config bastion"
echo "  SSH private:   ssh -F config/ssh_config private"
echo ""
echo "Or use the connection scripts:"
echo "  ./scripts/connect_bastion.sh"
echo "  ./scripts/connect_private.sh"
echo ""
