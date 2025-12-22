#!/bin/bash
#
# First Time Setup Script - Configuration Validation Only
#
# This script validates the environment and configuration:
# 1. Check prerequisites (Terraform, AWS CLI, ssh-keygen, curl)
# 2. Validate config/user.conf exists and is readable
# 3. Verify AWS credentials work
# 4. Detect public IP (for terraform.tfvars)
# 5. Check/generate SSH keys
# 6. Create terraform.tfvars from config
# 7. Run terraform init
#
# Usage:
#   ./scripts/first_time_setup.sh
#
# This script does NOT deploy infrastructure.
# After running this script, use test_infrastructure.sh to deploy and test.
#

set -e

# ==============================================================================
# Setup
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Create required directories (needed for fresh git clones)
mkdir -p "$PROJECT_ROOT/logs"
mkdir -p "$PROJECT_ROOT/config"
mkdir -p "$PROJECT_ROOT/backup"
mkdir -p "$SCRIPT_DIR/current_state"

source "$SCRIPT_DIR/lib/common.sh"

# Initialize logging
init_logging "first_time_setup"
clean_old_logs 10

# ==============================================================================
# Backup Cleanup
# ==============================================================================

cleanup_provider_backups() {
    log_step "Checking for Backup Files in providers/"

    local backup_dir="$PROJECT_ROOT/backup"
    local providers_dir="$PROJECT_ROOT/providers"
    local moved_count=0

    # Find and move backup files from providers/ to backup/
    for backup_file in "$providers_dir"/*.backup* "$providers_dir"/terraform.tfstate.backup; do
        if [[ -f "$backup_file" ]]; then
            local filename=$(basename "$backup_file")
            mv "$backup_file" "$backup_dir/$filename"
            log_info "Moved: $filename -> backup/"
            ((moved_count++))
        fi
    done

    if [[ $moved_count -gt 0 ]]; then
        print_result "Moved $moved_count backup file(s) to backup/" "pass"
    else
        print_result "No backup files in providers/ (clean)" "pass"
    fi

    return 0
}

# ==============================================================================
# Prerequisite Checks
# ==============================================================================

check_prerequisites() {
    log_step "Checking Prerequisites"

    local failed=0

    # Check Terraform
    if command -v terraform &> /dev/null; then
        local tf_version=$(terraform version -json 2>/dev/null | grep -o '"terraform_version":"[^"]*"' | cut -d'"' -f4)
        if [[ -z "$tf_version" ]]; then
            tf_version=$(terraform version | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
        fi
        print_result "Terraform v$tf_version" "pass"
    else
        print_result "Terraform not installed" "fail"
        failed=1
    fi

    # Check AWS CLI
    if command -v aws &> /dev/null; then
        local aws_version=$(aws --version 2>&1 | cut -d' ' -f1 | cut -d'/' -f2)
        print_result "AWS CLI v$aws_version" "pass"
    else
        print_result "AWS CLI not installed" "fail"
        failed=1
    fi

    # Check ssh-keygen
    if command -v ssh-keygen &> /dev/null; then
        print_result "ssh-keygen available" "pass"
    else
        print_result "ssh-keygen not installed" "fail"
        failed=1
    fi

    # Check curl
    if command -v curl &> /dev/null; then
        print_result "curl available" "pass"
    else
        print_result "curl not installed" "fail"
        failed=1
    fi

    if [[ $failed -eq 1 ]]; then
        log_error "Missing prerequisites. Please install required tools."
        return 1
    fi

    return 0
}

# ==============================================================================
# Configuration Validation
# ==============================================================================

validate_config() {
    log_step "Validating Configuration"

    # Check if config file exists
    if [[ -f "$CONFIG_FILE" ]]; then
        print_result "Config file exists: config/user.conf" "pass"
    else
        # Create from example if available
        local example_file="$SCRIPT_DIR/templates/user.conf.example"
        if [[ -f "$example_file" ]]; then
            cp "$example_file" "$CONFIG_FILE"
            print_result "Created config/user.conf from example" "pass"
            # Reload config
            load_user_config
            setup_aws_env
        else
            print_result "Config file not found" "fail"
            return 1
        fi
    fi

    # Validate required settings
    log_info "Configuration values:"
    log_info "  AWS_PROFILE:    ${AWS_PROFILE:-<not set>}"
    log_info "  AWS_REGION:     $AWS_REGION"
    log_info "  NAME_PREFIX:    $NAME_PREFIX"
    log_info "  SSH_KEY_PATH:   $SSH_KEY_PATH"
    log_info "  SSH_KEY_TYPE:   $SSH_KEY_TYPE"

    return 0
}

# ==============================================================================
# AWS Credential Validation
# ==============================================================================

validate_aws_credentials() {
    log_step "Validating AWS Credentials"

    # Ensure AWS environment is set
    setup_aws_env

    if verify_aws_credentials; then
        save_state "aws_validated" "true"
        return 0
    else
        save_state "aws_validated" "false"
        return 1
    fi
}

# ==============================================================================
# Public IP Detection
# ==============================================================================

detect_public_ip() {
    log_step "Detecting Public IP"

    # Check if already set in config
    if [[ "$ADMIN_IP_CIDR" != "auto" ]] && [[ -n "$ADMIN_IP_CIDR" ]]; then
        log_info "Using configured IP: $ADMIN_IP_CIDR"
        save_state "admin_ip" "$ADMIN_IP_CIDR"
        print_result "Admin IP configured" "pass"
        return 0
    fi

    # Auto-detect
    local ip=$(get_my_public_ip)
    if [[ -n "$ip" ]]; then
        ADMIN_IP_CIDR="${ip}/32"
        save_state "admin_ip" "$ADMIN_IP_CIDR"
        print_result "Detected public IP: $ip" "pass"
        return 0
    else
        print_result "Could not detect public IP" "fail"
        log_error "Set ADMIN_IP_CIDR manually in config/user.conf"
        return 1
    fi
}

# ==============================================================================
# SSH Key Setup
# ==============================================================================

setup_ssh_keys() {
    log_step "Checking SSH Keys"

    if check_ssh_key "$SSH_KEY_PATH"; then
        local key_type=$(ssh-keygen -l -f "${SSH_KEY_PATH}.pub" 2>/dev/null | awk '{print $NF}' | tr -d '()')
        print_result "SSH key exists: $SSH_KEY_PATH ($key_type)" "pass"
        save_state "ssh_key_path" "$SSH_KEY_PATH"
        return 0
    fi

    log_info "Generating $SSH_KEY_TYPE SSH key pair..."

    # Create directory if needed
    mkdir -p "$(dirname "$SSH_KEY_PATH")"
    chmod 700 "$(dirname "$SSH_KEY_PATH")"

    # Generate key
    if ssh-keygen -t "$SSH_KEY_TYPE" -f "$SSH_KEY_PATH" -N "" -C "${NAME_PREFIX}-bastion" &>/dev/null; then
        chmod 600 "$SSH_KEY_PATH"
        chmod 644 "${SSH_KEY_PATH}.pub"
        print_result "Generated SSH key: $SSH_KEY_PATH" "pass"
        save_state "ssh_key_path" "$SSH_KEY_PATH"
        return 0
    else
        print_result "Failed to generate SSH key" "fail"
        return 1
    fi
}

# ==============================================================================
# Terraform Configuration
# ==============================================================================

create_tfvars() {
    log_step "Creating Terraform Variables"

    local tfvars_file="$TERRAFORM_DIR/terraform.tfvars"
    local backup_dir="$PROJECT_ROOT/backup"

    # Backup existing to backup/ directory
    if [[ -f "$tfvars_file" ]]; then
        local backup="$backup_dir/terraform.tfvars.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$tfvars_file" "$backup"
        log_info "Backed up existing terraform.tfvars to backup/"
    fi

    # Load admin IP from state
    local admin_ip=$(load_state "admin_ip" "$ADMIN_IP_CIDR")

    # Create tfvars
    cat > "$tfvars_file" << EOF
# Terraform Variables - Generated by first_time_setup.sh
# Generated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
#
# Source: config/user.conf
# To regenerate: ./scripts/first_time_setup.sh

# AWS Region
region = "${AWS_REGION}"

# Availability Zone
availability_zone = "${AVAILABILITY_ZONE}"

# Resource naming prefix
name_prefix = "${NAME_PREFIX}"

# Admin IP for SSH access (auto-detected or from config)
admin_ip_cidr = "${admin_ip}"

# Network configuration
vpc_cidr            = "${VPC_CIDR:-10.22.0.0/16}"
public_subnet_cidr  = "${PUBLIC_SUBNET_CIDR:-10.22.5.0/24}"
private_subnet_cidr = "${PRIVATE_SUBNET_CIDR:-10.22.6.0/24}"

# SSH key path
ssh_public_key_path = "${SSH_KEY_PATH}.pub"

# Instance types
bastion_instance_type = "${BASTION_INSTANCE_TYPE:-t3.micro}"
private_instance_type = "${PRIVATE_INSTANCE_TYPE:-t3.micro}"
EOF

    print_result "Created providers/terraform.tfvars" "pass"
    return 0
}

# ==============================================================================
# Terraform Initialization
# ==============================================================================

init_terraform() {
    log_step "Initializing Terraform"

    # Ensure AWS environment is set
    setup_aws_env

    if run_terraform init -input=false; then
        print_result "Terraform initialized" "pass"
        save_state "terraform_initialized" "true"
        return 0
    else
        print_result "Terraform init failed" "fail"
        return 1
    fi
}

# ==============================================================================
# Summary
# ==============================================================================

print_summary() {
    echo ""
    print_separator
    log_success "First Time Setup Complete!"
    print_separator
    echo ""
    echo "Configuration:"
    echo "  AWS Profile:  ${AWS_PROFILE:-default}"
    echo "  AWS Region:   $AWS_REGION"
    echo "  Admin IP:     $(load_state 'admin_ip')"
    echo "  SSH Key:      $SSH_KEY_PATH"
    echo ""
    echo "Next steps:"
    echo ""
    echo "  1. Deploy and test infrastructure:"
    echo "     ./scripts/test_infrastructure.sh"
    echo ""
    echo "  OR manually:"
    echo ""
    echo "  2. Deploy infrastructure:"
    echo "     ./scripts/deploy.sh"
    echo ""
    echo "  3. Generate connection configs:"
    echo "     ./scripts/generate_config.sh"
    echo ""
    echo "  4. Connect:"
    echo "     ./scripts/connect_bastion.sh"
    echo "     ./scripts/connect_private.sh"
    echo ""
    print_separator
}

# ==============================================================================
# Main
# ==============================================================================

main() {
    echo ""
    print_separator
    echo "  Terraform Bastion Infrastructure - First Time Setup"
    print_separator

    # Clear previous state
    clear_state

    # Clean up any backup files in providers/
    cleanup_provider_backups

    # Run validation steps
    check_prerequisites || exit 1
    validate_config || exit 1
    validate_aws_credentials || exit 1
    detect_public_ip || exit 1
    setup_ssh_keys || exit 1
    create_tfvars || exit 1
    init_terraform || exit 1

    # Save completion state
    save_state "setup_completed" "$(date -u +"%Y-%m-%d %H:%M:%S UTC")"

    print_summary
    finalize_logging
}

main "$@"
