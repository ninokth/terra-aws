# Scripts Directory

Helper scripts for managing AWS Terraform infrastructure.

All scripts read configuration from `config/user.conf` and automatically set up the AWS environment (AWS_PROFILE, AWS_REGION).

**CI/CD Ready**: All scripts are designed as self-contained executables with proper exit codes, logging, and no interactive prompts (when using `-auto-approve` flags). They can be integrated into CI/CD pipelines such as Jenkins, Azure DevOps, GitHub Actions, or GitLab CI.

## Quick Start for Third Parties

If you cloned this repository and want to deploy to your own AWS account:

### Prerequisites

Before running any scripts, ensure you have completed:

1. **Terraform Installation** - See [docs/terraform-installation.md](../docs/terraform-installation.md)
   - Terraform 1.x installed and in PATH
   - Verify: `terraform version`

2. **AWS Account Setup** - See [docs/aws-account-setup.md](../docs/aws-account-setup.md)
   - IAM user `terraform-admin` with required permissions
   - Access keys generated
   - `~/.aws/credentials` configured with `[terraform]` profile
   - Verify: `aws sts get-caller-identity --profile terraform`

Once prerequisites are complete, proceed with deployment:

```bash
# 1. Edit configuration (optional - defaults work for most cases)
cp config/user.conf.example config/user.conf
vim config/user.conf  # Set AWS_PROFILE, region, etc.

# 2. Run first-time setup (validates config, creates terraform.tfvars)
./scripts/first_time_setup.sh

# 3. Deploy infrastructure
./scripts/deploy.sh

# 4. Test infrastructure
./scripts/test_infrastructure.sh

# 5. When done, destroy
./scripts/destroy.sh
```

## Complete Workflow

> **Prerequisites**: Terraform installed, AWS CLI configured with `~/.aws/credentials` containing a `[terraform]` profile. See [Prerequisites](#prerequisites) above.

### Step 1: First Time Setup (Configuration Only)

```bash
./scripts/first_time_setup.sh
```

This validates your environment and creates configuration:
- Checks prerequisites (Terraform, AWS CLI, ssh-keygen, curl)
- Validates AWS credentials
- Auto-detects your public IP for security groups
- Generates SSH keys if needed
- Creates `terraform.tfvars` from config
- Runs `terraform init`

**Does NOT deploy infrastructure.**

### Step 2: Deploy Infrastructure

```bash
./scripts/deploy.sh
```

This deploys and waits for readiness:
- Runs `terraform apply -auto-approve`
- Waits for bastion SSH to be ready
- Waits for private host SSH to be ready (via bastion)
- Waits for NAT/nftables to be configured
- Saves state (IPs, deployment status)

### Step 3: Test Infrastructure

```bash
./scripts/test_infrastructure.sh
```

This runs automated end-to-end validation with detailed logging:

- Tests SSH access to bastion
- Tests SSH access to private host (via ProxyJump)
- Tests NAT connectivity (internet from private host)
- Reports pass/fail for each test
- Logs saved to `logs/test_infrastructure_*.log`

**Manual Testing**: You can also connect directly and run tests from CLI:

```bash
# Connect to bastion host
./scripts/connect_bastion.sh

# Connect to private host (via bastion)
./scripts/connect_private.sh
```

From the private host, verify NAT is working:

```bash
ping -c 3 8.8.8.8                    # Test internet connectivity
curl -4 https://api.ipify.org        # Should show bastion's public IP
nslookup google.com                  # Test DNS resolution
```

### Step 4: Destroy Infrastructure

```bash
./scripts/destroy.sh
```

This destroys and verifies cleanup:
- Runs `terraform destroy -auto-approve`
- Verifies Terraform state is empty
- Checks for remaining AWS resources (EIPs, EC2, VPCs, key pairs)
- Confirms zero-cost state

## Script Descriptions

### Main Workflow Scripts

| Script | Description |
|--------|-------------|
| `first_time_setup.sh` | Validates config, creates terraform.tfvars, runs terraform init |
| `deploy.sh` | Deploys infrastructure, waits for instances to be ready |
| `test_infrastructure.sh` | Tests SSH and NAT connectivity |
| `destroy.sh` | Destroys infrastructure, verifies cleanup |

### Connection Scripts

| Script | Description |
|--------|-------------|
| `connect_bastion.sh` | SSH to bastion host with agent forwarding |
| `connect_private.sh` | SSH to private host via ProxyJump |

### Utility Scripts

| Script | Description |
|--------|-------------|
| `generate_config.sh` | Generate connection config files (after deploy) |
| `setup_ssh_key.sh` | Generate SSH key pair for deployment |
| `cleanup_ssh_key.sh` | Remove SSH key pair (after destroying infrastructure) |
| `cleanup_artifacts.sh` | Remove temporary files (plan files, crash logs, etc.) |

### Why generate_config.sh?

Every time you deploy infrastructure, AWS assigns new IP addresses. The `generate_config.sh` script extracts current IPs from Terraform state and generates ready-to-use configuration files:

```bash
./scripts/generate_config.sh
```

**Generated files in `config/`:**

| File | Format | Use Case |
|------|--------|----------|
| `infrastructure.json` | JSON | Parsing in scripts, CI/CD pipelines |
| `infrastructure.ini` | INI | Configuration management tools |
| `infrastructure.env` | Shell | Source in terminal for aliases and variables |
| `ssh_config` | SSH | Append to `~/.ssh/config` for easy connections |

**Example usage:**

```bash
# Use shell aliases (after sourcing env file)
source config/infrastructure.env
ssh-bastion                      # Connect to bastion
ssh-private                      # Connect to private host via ProxyJump

# Or use SSH config directly
ssh -F config/ssh_config bastion
ssh -F config/ssh_config private

# Or append to your SSH config for permanent use
cat config/ssh_config >> ~/.ssh/config
ssh bastion
ssh private
```

**When to run:** After each `terraform apply` or `./scripts/deploy.sh` to update configuration with new IP addresses.

## Configuration

All scripts read from `config/user.conf`. Key settings:

```bash
# AWS Configuration
AWS_PROFILE="terraform"        # AWS CLI profile name
AWS_REGION="eu-north-1"        # Deployment region

# Network
ADMIN_IP_CIDR="auto"           # Your IP (auto-detected or manual)

# SSH
SSH_KEY_PATH="auto"            # SSH key location
SSH_KEY_TYPE="ed25519"         # Key algorithm
SSH_USER="ubuntu"              # EC2 SSH user

# Naming
NAME_PREFIX="tf-demo"          # Resource name prefix
```

See `config/user.conf.example` for all available options.

## Directory Structure

```text
scripts/
├── first_time_setup.sh    # Config validation and setup
├── deploy.sh              # Deploy infrastructure
├── test_infrastructure.sh # Test connectivity
├── destroy.sh             # Destroy and verify cleanup
├── connect_bastion.sh     # SSH to bastion
├── connect_private.sh     # SSH to private host
├── generate_config.sh     # Generate config files
├── setup_ssh_key.sh       # Generate SSH keys
├── cleanup_ssh_key.sh     # Remove SSH keys
├── lib/
│   └── common.sh          # Shared functions library
├── templates/
│   └── user.conf.example  # Config template (copied to config/)
├── current_state/         # Runtime state files (gitignored)
└── README.md              # This file

logs/                      # Log files from script runs (gitignored)
```

## How Scripts Communicate

Scripts share state through `scripts/current_state/` directory:

| State File | Description |
|------------|-------------|
| `setup_completed` | Timestamp when first_time_setup completed |
| `terraform_initialized` | Whether terraform init succeeded |
| `aws_validated` | AWS credentials validated |
| `admin_ip` | Detected admin IP for security group |
| `bastion_ip` | Current bastion public IP |
| `private_ip` | Current private host IP |
| `infrastructure_deployed` | Deployment status |
| `nat_ready` | NAT connectivity status |
| `cleanup_verified` | Cleanup verification status |

## Logging

All scripts write logs to the `logs/` directory:
- `logs/first_time_setup_YYYYMMDD_HHMMSS.log`
- `logs/deploy_YYYYMMDD_HHMMSS.log`
- `logs/test_infrastructure_YYYYMMDD_HHMMSS.log`
- `logs/destroy_YYYYMMDD_HHMMSS.log`

Logs are automatically rotated (keeps last 10 files).

## AWS Environment

Each script automatically:
1. Loads `config/user.conf`
2. Exports `AWS_PROFILE` and `AWS_REGION`
3. All AWS CLI and Terraform commands use these settings

You don't need to manually export AWS variables before running scripts.

## Troubleshooting

### AWS Credentials Not Working

```bash
# Check if credentials are configured
aws configure list --profile terraform

# Test credentials
aws sts get-caller-identity --profile terraform
```

### SSH Key Issues

```bash
# Check if key exists
ls -la ~/.ssh/id_ed25519*

# Generate new key (uses config from user.conf)
./scripts/setup_ssh_key.sh

# Or remove and regenerate
./scripts/cleanup_ssh_key.sh
./scripts/setup_ssh_key.sh

# Then re-run first_time_setup to update terraform.tfvars
./scripts/first_time_setup.sh
```

### Terraform State Issues

```bash
# Check Terraform state
terraform -chdir=providers show

# Force destroy
terraform -chdir=providers destroy -auto-approve
```

### View Logs

```bash
# View latest log
cat logs/$(ls -t logs/ | head -1)

# View all logs
ls -la logs/
```

### NAT Not Working

The NAT is configured via nftables user_data script on the bastion. It takes 30-60 seconds after instance boot to be ready. The deploy.sh script waits for this automatically.

If NAT fails during testing:
```bash
# Check nftables on bastion
ssh -i ~/.ssh/id_ed25519 ubuntu@<bastion-ip> "sudo nft list ruleset"

# Check IP forwarding
ssh -i ~/.ssh/id_ed25519 ubuntu@<bastion-ip> "cat /proc/sys/net/ipv4/ip_forward"
```
