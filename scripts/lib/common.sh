#!/bin/bash
#
# Common Functions Library for Terraform Bastion Scripts
#
# This file provides shared functions, configuration loading, and AWS environment setup
# for all scripts in the project.
#
# Usage in other scripts:
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   source "$SCRIPT_DIR/lib/common.sh"
#
# IMPORTANT: Each script that sources this file will automatically:
#   1. Load user configuration from config/user.conf
#   2. Export AWS_PROFILE and AWS_REGION for subprocesses (terraform, aws cli)
#

# ==============================================================================
# Path Configuration
# ==============================================================================

# Determine project root (works from any script location)
if [[ -z "$PROJECT_ROOT" ]]; then
    if [[ -n "$SCRIPT_DIR" ]]; then
        PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
    else
        PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    fi
fi

CONFIG_FILE="$PROJECT_ROOT/config/user.conf"
TERRAFORM_DIR="$PROJECT_ROOT/providers"
STATE_DIR="$PROJECT_ROOT/scripts/current_state"
LOGS_DIR="$PROJECT_ROOT/logs"

# ==============================================================================
# Color Definitions
# ==============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# ==============================================================================
# Logging Functions
# ==============================================================================

# Current log file (set by init_logging)
CURRENT_LOG_FILE=""

log_info() {
    local msg="${BLUE}[INFO]${NC} $1"
    echo -e "$msg"
    [[ -n "$CURRENT_LOG_FILE" ]] && echo "[INFO] $1" >> "$CURRENT_LOG_FILE" || true
}

log_success() {
    local msg="${GREEN}[OK]${NC} $1"
    echo -e "$msg"
    [[ -n "$CURRENT_LOG_FILE" ]] && echo "[OK] $1" >> "$CURRENT_LOG_FILE" || true
}

log_warning() {
    local msg="${YELLOW}[WARN]${NC} $1"
    echo -e "$msg"
    [[ -n "$CURRENT_LOG_FILE" ]] && echo "[WARN] $1" >> "$CURRENT_LOG_FILE" || true
}

log_error() {
    local msg="${RED}[ERROR]${NC} $1"
    echo -e "$msg"
    [[ -n "$CURRENT_LOG_FILE" ]] && echo "[ERROR] $1" >> "$CURRENT_LOG_FILE" || true
}

log_debug() {
    if [[ "${VERBOSE:-false}" == "true" ]]; then
        local msg="${CYAN}[DEBUG]${NC} $1"
        echo -e "$msg"
        [[ -n "$CURRENT_LOG_FILE" ]] && echo "[DEBUG] $1" >> "$CURRENT_LOG_FILE" || true
    fi
}

log_step() {
    local msg="${BOLD}>>> $1${NC}"
    echo -e "\n$msg"
    [[ -n "$CURRENT_LOG_FILE" ]] && echo -e "\n>>> $1" >> "$CURRENT_LOG_FILE" || true
}

# ==============================================================================
# Logging Initialization
# ==============================================================================

# Initialize logging for a script
# Usage: init_logging "script_name"
init_logging() {
    local script_name="$1"
    local timestamp=$(date +"%Y%m%d_%H%M%S")

    mkdir -p "$LOGS_DIR"
    CURRENT_LOG_FILE="$LOGS_DIR/${script_name}_${timestamp}.log"

    # Write header to log
    echo "=============================================" > "$CURRENT_LOG_FILE"
    echo "Log: $script_name" >> "$CURRENT_LOG_FILE"
    echo "Started: $(date)" >> "$CURRENT_LOG_FILE"
    echo "=============================================" >> "$CURRENT_LOG_FILE"
    echo "" >> "$CURRENT_LOG_FILE"
}

# Finalize logging
finalize_logging() {
    if [[ -n "$CURRENT_LOG_FILE" ]]; then
        echo "" >> "$CURRENT_LOG_FILE"
        echo "=============================================" >> "$CURRENT_LOG_FILE"
        echo "Completed: $(date)" >> "$CURRENT_LOG_FILE"
        echo "=============================================" >> "$CURRENT_LOG_FILE"
        log_info "Log saved to: $CURRENT_LOG_FILE"
    fi
}

# Clean old log files (keep last N)
clean_old_logs() {
    local keep_count="${1:-10}"
    local log_pattern="$LOGS_DIR/*.log"

    # Count log files
    local log_count=$(ls -1 $log_pattern 2>/dev/null | wc -l)

    if [[ $log_count -gt $keep_count ]]; then
        local to_delete=$((log_count - keep_count))
        ls -1t $log_pattern | tail -n $to_delete | xargs rm -f
        log_debug "Cleaned $to_delete old log files"
    fi
}

# ==============================================================================
# State Management
# ==============================================================================

# Save a state value
# Usage: save_state "key" "value"
save_state() {
    local key="$1"
    local value="$2"
    mkdir -p "$STATE_DIR"
    echo "$value" > "$STATE_DIR/$key"
}

# Load a state value
# Usage: value=$(load_state "key")
load_state() {
    local key="$1"
    local default="${2:-}"
    local file="$STATE_DIR/$key"

    if [[ -f "$file" ]]; then
        cat "$file"
    else
        echo "$default"
    fi
}

# Check if state exists
# Usage: if state_exists "key"; then ...
state_exists() {
    local key="$1"
    [[ -f "$STATE_DIR/$key" ]]
}

# Clear all state
clear_state() {
    rm -rf "$STATE_DIR"/*
    log_debug "Cleared all state files"
}

# ==============================================================================
# Configuration Loading
# ==============================================================================

# Load user configuration from config/user.conf
load_user_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
        log_debug "Loaded configuration from: $CONFIG_FILE"
    else
        log_debug "No user config found, using defaults"
    fi

    # Set defaults for any missing values
    AWS_PROFILE="${AWS_PROFILE:-}"
    AWS_REGION="${AWS_REGION:-eu-north-1}"
    AVAILABILITY_ZONE="${AVAILABILITY_ZONE:-${AWS_REGION}a}"
    NAME_PREFIX="${NAME_PREFIX:-tf-demo}"
    SSH_KEY_PATH="${SSH_KEY_PATH:-auto}"
    SSH_KEY_TYPE="${SSH_KEY_TYPE:-ed25519}"
    SSH_USER="${SSH_USER:-ubuntu}"
    VERBOSE="${VERBOSE:-false}"

    # Resolve auto values
    if [[ "$SSH_KEY_PATH" == "auto" ]]; then
        SSH_KEY_PATH="$HOME/.ssh/id_${SSH_KEY_TYPE}"
    fi
}

# ==============================================================================
# AWS Environment Setup
# ==============================================================================

# Setup AWS environment - MUST be called by each script
# This exports AWS_PROFILE and AWS_REGION so that terraform and aws cli work
setup_aws_env() {
    # Export AWS variables for subprocesses
    if [[ -n "$AWS_PROFILE" ]]; then
        export AWS_PROFILE="$AWS_PROFILE"
    fi
    if [[ -n "$AWS_REGION" ]]; then
        export AWS_REGION="$AWS_REGION"
    fi

    # Also export as AWS_DEFAULT_REGION for some tools
    export AWS_DEFAULT_REGION="$AWS_REGION"

    log_debug "AWS environment set: PROFILE=${AWS_PROFILE:-default}, REGION=$AWS_REGION"
}

# Verify AWS credentials are working
verify_aws_credentials() {
    log_info "Verifying AWS credentials..."

    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI not installed"
        return 1
    fi

    local identity
    if identity=$(aws sts get-caller-identity 2>&1); then
        local account_id=$(echo "$identity" | grep -o '"Account": "[^"]*"' | cut -d'"' -f4)
        local arn=$(echo "$identity" | grep -o '"Arn": "[^"]*"' | cut -d'"' -f4)
        log_success "AWS credentials valid"
        log_info "  Account: $account_id"
        log_info "  Identity: $arn"

        # Save to state
        save_state "aws_account_id" "$account_id"
        save_state "aws_identity" "$arn"
        return 0
    else
        log_error "AWS credentials invalid or not configured"
        log_error "  Run: aws configure --profile ${AWS_PROFILE:-default}"
        return 1
    fi
}

# ==============================================================================
# Terraform Functions
# ==============================================================================

# Run terraform command with proper environment
run_terraform() {
    setup_aws_env
    terraform -chdir="$TERRAFORM_DIR" "$@"
}

# Get a single Terraform output value
get_terraform_output() {
    local output_name="$1"
    setup_aws_env
    terraform -chdir="$TERRAFORM_DIR" output -raw "$output_name" 2>/dev/null
}

# Get bastion public IP
get_bastion_public_ip() {
    get_terraform_output "bastion_public_ip"
}

# Get bastion private IP
get_bastion_private_ip() {
    get_terraform_output "bastion_private_ip"
}

# Get private instance IP
get_private_instance_ip() {
    get_terraform_output "private_instance_private_ip"
}

# Check if Terraform has been applied (resources exist in state)
check_terraform_deployed() {
    setup_aws_env
    local resource_count=$(terraform -chdir="$TERRAFORM_DIR" state list 2>/dev/null | wc -l)
    if [[ "$resource_count" -gt 0 ]]; then
        return 0
    fi
    return 1
}

# ==============================================================================
# Validation Functions
# ==============================================================================

# Check if SSH key exists
check_ssh_key() {
    local key_path="${1:-$SSH_KEY_PATH}"
    if [[ -f "$key_path" ]] && [[ -f "${key_path}.pub" ]]; then
        return 0
    fi
    return 1
}

# Validate IP address format
validate_ip() {
    local ip="$1"
    if [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        return 0
    fi
    return 1
}

# ==============================================================================
# SSH Functions
# ==============================================================================

# Standard SSH options for all connections
SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o ConnectTimeout=30"

# SSH to bastion
ssh_bastion() {
    local cmd="${1:-}"
    local bastion_ip=$(get_bastion_public_ip)

    if [[ -z "$bastion_ip" ]]; then
        log_error "Bastion IP not available"
        return 1
    fi

    if [[ -n "$cmd" ]]; then
        ssh $SSH_OPTS -i "$SSH_KEY_PATH" "${SSH_USER}@${bastion_ip}" "$cmd"
    else
        ssh $SSH_OPTS -A -i "$SSH_KEY_PATH" "${SSH_USER}@${bastion_ip}"
    fi
}

# SSH to private host via bastion
ssh_private() {
    local cmd="${1:-}"
    local bastion_ip=$(get_bastion_public_ip)
    local private_ip=$(get_private_instance_ip)

    if [[ -z "$bastion_ip" ]] || [[ -z "$private_ip" ]]; then
        log_error "Bastion or private IP not available"
        return 1
    fi

    local proxy_cmd="ssh -W %h:%p $SSH_OPTS -i $SSH_KEY_PATH ${SSH_USER}@${bastion_ip}"

    if [[ -n "$cmd" ]]; then
        ssh $SSH_OPTS -i "$SSH_KEY_PATH" -o "ProxyCommand=$proxy_cmd" "${SSH_USER}@${private_ip}" "$cmd"
    else
        ssh $SSH_OPTS -A -i "$SSH_KEY_PATH" -o "ProxyCommand=$proxy_cmd" "${SSH_USER}@${private_ip}"
    fi
}

# ==============================================================================
# Utility Functions
# ==============================================================================

# Get current public IP
get_my_public_ip() {
    local ip=""
    local services=(
        "https://api.ipify.org"
        "https://ifconfig.me"
        "https://icanhazip.com"
        "https://checkip.amazonaws.com"
    )

    for service in "${services[@]}"; do
        ip=$(curl -s --max-time 5 "$service" 2>/dev/null | tr -d '[:space:]')
        if validate_ip "$ip"; then
            echo "$ip"
            return 0
        fi
    done

    return 1
}

# Print a separator line
print_separator() {
    echo "=============================================="
}

# Print test result
print_result() {
    local test_name="$1"
    local status="$2"  # pass, fail, skip

    case "$status" in
        pass)
            echo -e "  ${GREEN}PASS${NC}  $test_name"
            [[ -n "$CURRENT_LOG_FILE" ]] && echo "  PASS  $test_name" >> "$CURRENT_LOG_FILE" || true
            ;;
        fail)
            echo -e "  ${RED}FAIL${NC}  $test_name"
            [[ -n "$CURRENT_LOG_FILE" ]] && echo "  FAIL  $test_name" >> "$CURRENT_LOG_FILE" || true
            ;;
        skip)
            echo -e "  ${YELLOW}SKIP${NC}  $test_name"
            [[ -n "$CURRENT_LOG_FILE" ]] && echo "  SKIP  $test_name" >> "$CURRENT_LOG_FILE" || true
            ;;
    esac
}

# Prompt user for confirmation
# Usage: confirm "message" "default"
# Returns 0 for yes, 1 for no
confirm() {
    local prompt="$1"
    local default="${2:-n}"  # default to no

    local yn_hint
    if [[ "$default" == "y" ]]; then
        yn_hint="[Y/n]"
    else
        yn_hint="[y/N]"
    fi

    while true; do
        read -r -p "$prompt $yn_hint " response
        response="${response:-$default}"
        case "$response" in
            [yY][eE][sS]|[yY]) return 0 ;;
            [nN][oO]|[nN]) return 1 ;;
            *) echo "Please answer yes or no." ;;
        esac
    done
}

# ==============================================================================
# Initialization
# ==============================================================================

# Auto-load config when this library is sourced
load_user_config

# Auto-setup AWS environment
setup_aws_env
