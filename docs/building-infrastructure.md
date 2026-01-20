# Building Infrastructure - Complete Deployment Guide

This guide walks through deploying the AWS bastion host infrastructure from scratch, including testing and validation.

## Prerequisites

Before you begin, ensure you have completed:

1. ✅ [Terraform Installation](terraform-installation.md)
2. ✅ [AWS Account Setup](aws-account-setup.md)
3. ✅ AWS credentials configured and tested

## Overview

The deployment process involves:

1. Setting up SSH keys
2. Configuring infrastructure variables
3. Setting AWS credentials in your shell
4. Initializing Terraform
5. Deploying infrastructure
6. Testing connectivity
7. Validating NAT functionality

## Step 1: Generate SSH Keys

SSH keys are required to access the EC2 instances.

```bash
# Navigate to project root
cd <project_root>

# Generate Ed25519 SSH key pair
./scripts/setup_ssh_key.sh
```

**What this does**:

- Creates `~/.ssh/id_ed25519` (private key - keep secret)
- Creates `~/.ssh/id_ed25519.pub` (public key - uploaded to AWS)
- Sets correct permissions (600 for private, 644 for public)

**Expected output**:

```
SSH Key Setup Script
====================

Generating Ed25519 SSH key pair...
✓ SSH key pair created successfully

Location:
  Private key: ~/.ssh/id_ed25519
  Public key:  ~/.ssh/id_ed25519.pub
```

**Verify keys exist**:

```bash
ls -la ~/.ssh/id_ed25519*
```

Should show:

```
-rw------- 1 user user  464 Dec 21 10:00 ~/.ssh/id_ed25519
-rw-r--r-- 1 user user  106 Dec 21 10:00 ~/.ssh/id_ed25519.pub
```

## Step 2: Configure Infrastructure Variables

Create your configuration from the example template.

```bash
# Copy example configuration
cp providers/terraform.tfvars.example providers/terraform.tfvars

# Edit with your settings
vim providers/terraform.tfvars
# or
nano providers/terraform.tfvars
```

**Required: Set Your Admin IP Address**

Find your public IP address:

```bash
curl -s https://api.ipify.org
```

This will return your IP address (e.g., `203.0.113.45`).

**Edit `providers/terraform.tfvars`**:

```hcl
# AWS Region
region = "eu-north-1"

# Resource naming prefix
name_prefix = "tf-demo"

# ⚠️ REQUIRED: Your public IP address for SSH access
admin_ip_cidr = "203.0.113.45/32"  # Replace with YOUR IP
```

**Why `/32`?**

The `/32` means exactly one IP address (most restrictive). This ensures only your workstation can SSH to the bastion.

**Optional variables** (uncomment to customize):

```hcl
# Network configuration (defaults shown)
# vpc_cidr              = "10.22.0.0/16"
# public_subnet_cidr    = "10.22.5.0/24"
# private_subnet_cidr   = "10.22.6.0/24"
# availability_zone     = "eu-north-1a"

# SSH key path (if you used a different location)
# ssh_public_key_path   = "~/.ssh/id_ed25519.pub"

# Instance types (defaults shown)
# bastion_instance_type = "t3.micro"
# private_instance_type = "t3.micro"
```

## Step 3: Set AWS Credentials

Tell Terraform which AWS credentials to use.

```bash
# Set AWS profile and region
export AWS_PROFILE=terraform
export AWS_REGION=eu-north-1
```

**What these environment variables do**:

1. **`AWS_PROFILE=terraform`**:
   - Points to the `[terraform]` section in `~/.aws/credentials`
   - Contains your AWS Access Key ID and Secret Access Key
   - Tells Terraform which IAM user credentials to use

2. **`AWS_REGION=eu-north-1`**:
   - Sets the AWS region where infrastructure will be created
   - `eu-north-1` is Stockholm, Sweden
   - All resources (VPC, EC2, etc.) will be created in this region

**Why we need both**:

- Without `AWS_PROFILE`: Terraform won't know which credentials to use
- Without `AWS_REGION`: Terraform will require region in every command

**Verify they're set**:

```bash
# Check environment variables
echo "Profile: $AWS_PROFILE"
echo "Region: $AWS_REGION"

# Verify AWS credentials work
aws sts get-caller-identity --profile terraform
```

Expected output:

```json
{
    "UserId": "AIDAXXXXXXXXXXXXXXXXX",
    "Account": "<your_account_id>",
    "Arn": "arn:aws:iam::<your_account_id>:user/terraform-admin"
}
```

**⚠️ Important**: You must export these variables in every new terminal session, or add them to your `~/.bashrc`:

```bash
echo 'export AWS_PROFILE=terraform' >> ~/.bashrc
echo 'export AWS_REGION=eu-north-1' >> ~/.bashrc
source ~/.bashrc
```

## Step 4: Initialize Terraform

Initialize Terraform to download required providers.

```bash
# Navigate to providers directory (ROOT MODULE)
cd <project_root>/providers

# Initialize Terraform
terraform init
```

**What this does**:

- Downloads the AWS provider plugin (~200MB)
- Sets up the `.terraform/` directory
- Creates `.terraform.lock.hcl` (dependency lock file)
- Prepares the working directory

**Expected output**:

```
Initializing the backend...
Initializing modules...

Initializing provider plugins...
- Finding hashicorp/aws versions matching "~> 6.14"...
- Installing hashicorp/aws v6.14.0...
- Installed hashicorp/aws v6.14.0

Terraform has been successfully initialized!
```

**✅ Success indicators**:

- No errors
- "successfully initialized" message
- `.terraform/` directory created
- `.terraform.lock.hcl` file created

**Verify initialization**:

```bash
ls -la
```

Should show:

```
.terraform/
.terraform.lock.hcl
main.tf
outputs.tf
terraform.tfvars
terraform.tfvars.example
variables.tf
versions.tf
```

## Step 5: Plan Infrastructure Changes

Preview what Terraform will create before actually deploying.

```bash
# Generate execution plan
terraform plan
```

**What this does**:

- Validates your configuration
- Queries AWS for current state
- Shows what will be created/modified/destroyed
- Does NOT make any changes yet

**Expected output** (abbreviated):

```
Terraform will perform the following actions:

  # module.terraform_ws.module.bastion.aws_eip.bastion will be created
  + resource "aws_eip" "bastion" {
      + allocation_id        = (known after apply)
      + domain              = "vpc"
      + instance            = (known after apply)
      + public_ip           = (known after apply)
      ...
    }

  # module.terraform_ws.module.bastion.aws_instance.bastion will be created
  + resource "aws_instance" "bastion" {
      + ami                          = "ami-073130f74f5ffb161"
      + instance_type                = "t3.micro"
      + subnet_id                    = (known after apply)
      ...
    }

  # ... (many more resources)

Plan: 17 to add, 0 to change, 0 to destroy.
```

**Review the plan carefully**:

- **17 resources to add**: VPC, subnets, security groups, instances, etc.
- **0 to change**: No existing infrastructure
- **0 to destroy**: Nothing will be deleted

**⚠️ Common issues at this stage**:

- **No valid credentials**: Check `AWS_PROFILE` is set
- **Invalid admin_ip_cidr**: Check your IP is correct in `terraform.tfvars`
- **SSH key not found**: Check `~/.ssh/id_ed25519.pub` exists

## Step 6: Apply Infrastructure

Deploy the infrastructure to AWS.

```bash
# Deploy infrastructure
terraform apply
```

Terraform will show the plan again and ask for confirmation:

```
Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value:
```

**Type `yes` and press Enter**.

**What happens during apply**:

1. Validate AWS credentials (data source)
2. Create VPC, subnets, Internet Gateway, route tables
3. Create security groups
4. Upload SSH key to AWS, query AMI
5. Create bastion instance, allocate Elastic IP
6. Create private instance, configure NAT routing

**Expected output** (takes 2-3 minutes):

```
module.terraform_ws.data.aws_caller_identity.current: Reading...
module.terraform_ws.data.aws_caller_identity.current: Read complete after 0s

module.terraform_ws.module.vpc.aws_vpc.main: Creating...
module.terraform_ws.module.vpc.aws_vpc.main: Creation complete after 2s
module.terraform_ws.module.vpc.aws_subnet.public: Creating...
module.terraform_ws.module.vpc.aws_subnet.private: Creating...
module.terraform_ws.module.vpc.aws_internet_gateway.main: Creating...
...
module.terraform_ws.module.bastion.aws_instance.bastion: Still creating... [10s elapsed]
module.terraform_ws.module.bastion.aws_instance.bastion: Still creating... [20s elapsed]
module.terraform_ws.module.bastion.aws_instance.bastion: Creation complete after 25s
module.terraform_ws.module.bastion.aws_eip.bastion: Creating...
module.terraform_ws.module.bastion.aws_eip.bastion: Creation complete after 2s
...

Apply complete! Resources: 17 added, 0 changed, 0 destroyed.

Outputs:

account_id = "<your_account_id>"
ami_id = "ami-073130f74f5ffb161"
ami_name = "ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-20251212"
arn = "arn:aws:iam::<your_account_id>:user/terraform-admin"
bastion_instance_id = "i-0abc123def456789"
bastion_private_ip = "10.22.5.x"
bastion_public_ip = "X.X.X.X"
private_instance_id = "i-0def456abc789012"
private_instance_private_ip = "10.22.6.x"
vpc_id = "vpc-0abc123456789def0"
...
```

### Understanding the IP Addresses

The `10.22.x.x` range used in this infrastructure is one of three **private IP ranges** defined in RFC 1918. These ranges are reserved for internal networks and are not routable on the public internet:

| Range | CIDR Notation | Available Addresses | Common Use |
|-------|---------------|---------------------|------------|
| 10.0.0.0 – 10.255.255.255 | 10.0.0.0/8 | ~16.7 million | Large enterprises, cloud providers |
| 172.16.0.0 – 172.31.255.255 | 172.16.0.0/12 | ~1 million | Medium networks |
| 192.168.0.0 – 192.168.255.255 | 192.168.0.0/16 | ~65,000 | Home networks, small offices |

**Why 10.22.0.0/16?** There's no technical reason - it's simply a memorable, non-conflicting choice. You could use `172.16.0.0/16` or other ranges from the table above. The key is avoiding conflicts with your home/office network when using VPN connections.

> **Rule of thumb:** Never use `192.168.0.x` or `192.168.1.x` for cloud infrastructure. Home routers almost universally default to these ranges. When you connect via VPN, your laptop will have conflicting routes - packets destined for your cloud `192.168.1.50` might go to your home printer instead. Using `10.x.x.x` or `172.16.x.x` avoids this headache entirely.

#### AWS Reserved IP Addresses

AWS reserves **5 IP addresses** in every subnet. For our `10.22.5.0/24` public subnet:

| IP Address | Reserved For |
|------------|--------------|
| 10.22.5.0 | Network address |
| 10.22.5.1 | VPC router (default gateway) |
| 10.22.5.2 | AWS DNS server |
| 10.22.5.3 | Reserved for future use |
| 10.22.5.255 | Broadcast address |

This means in a `/24` subnet (256 addresses), only **251 are usable** for hosts.

#### Best Practices for IP Allocation

When designing networks, reserve address ranges for specific purposes:

| Range | Purpose |
|-------|---------|
| .1 – .10 | Infrastructure services (AWS uses .1-.3) |
| .11 – .20 | Network devices, load balancers |
| .21 – .240 | Hosts (EC2 instances, containers) |
| .241 – .253 | Reserved for expansion |
| .254 | Internal routers/NAT devices (convention) |
| .255 | Broadcast (unusable) |

**Why .254 for internal routers?** The `.1` address is typically claimed by cloud providers (AWS VPC router). Using `.254` for your own routing devices (like a bastion doing NAT) creates a clear convention: `.1` is the cloud gateway, `.254` is your internal router. This avoids confusion and conflicts.

In this infrastructure, AWS assigns IPs dynamically from the available pool (DHCP). For production environments, consider using **static private IPs** for critical infrastructure like bastion hosts.

**✅ Success indicators**:

- "Apply complete! Resources: 17 added, 0 changed, 0 destroyed."
- All outputs displayed
- `bastion_public_ip` shows an IP address

**Save the bastion public IP** - you'll need it for SSH access.

## Step 7: Wait for Instance Initialization

The instances need time to complete their user-data scripts (updates, nftables setup).

```bash
# Wait 2-3 minutes for instances to fully initialize
echo "Waiting for instances to complete initialization..."
sleep 180
```

**What's happening during this time**:

**Bastion host (pub_host-01)**:
- Setting hostname
- Running `apt-get update && apt-get upgrade`
- Installing nftables
- Configuring NAT with IP forwarding
- Starting nftables service

**Private host (prv_host-01)**:
- Setting hostname
- Running `apt-get update && apt-get upgrade`
- Completing cloud-init

## Step 8: Test SSH Access to Bastion

Test that you can SSH to the bastion host.

```bash
# Return to project root
cd <project_root>

# Connect to bastion using helper script
./scripts/connect_bastion.sh
```

**Or manually**:

```bash
# Get bastion IP from Terraform output
BASTION_IP=$(cd providers && terraform output -raw bastion_public_ip)

# SSH to bastion
ssh -A -i ~/.ssh/id_ed25519 ubuntu@${BASTION_IP}
```

**Expected result**: You should be connected to the bastion host.

```
ubuntu@pub-host-01:~$
```

**Verify bastion configuration**:

```bash
# Check hostname
hostname
# Output: pub-host-01

# Check IP forwarding is enabled
cat /proc/sys/net/ipv4/ip_forward
# Output: 1

# Check nftables NAT is configured
sudo nft list ruleset | grep masquerade
# Output: oifname "ens5" masquerade

# Check internet connectivity
curl -4 https://api.ipify.org
# Output: <bastion_public_ip>
```

**Exit bastion**:

```bash
exit
```

## Step 9: Test SSH Access to Private Host

Test that you can access the private host via ProxyJump.

```bash
# Connect to private host using helper script
./scripts/connect_private.sh
```

**Or manually**:

```bash
# Get IPs from Terraform output
BASTION_IP=$(cd providers && terraform output -raw bastion_public_ip)
PRIVATE_IP=$(cd providers && terraform output -raw private_instance_private_ip)

# SSH via ProxyJump
ssh -J ubuntu@${BASTION_IP} -i ~/.ssh/id_ed25519 ubuntu@${PRIVATE_IP}
```

**Expected result**: You should be connected to the private host through the bastion.

```
ubuntu@prv-host-01:~$
```

## Step 10: Validate NAT Functionality

Test that the private host can reach the internet through the bastion's NAT.

**From the private host**, run:

```bash
# Check hostname
hostname
# Output: prv-host-01

# Verify no public IP (should timeout or return nothing)
curl -s --max-time 5 http://169.254.169.254/latest/meta-data/public-ipv4
# Output: (empty or timeout - no public IP assigned)
```

> **What is 169.254.169.254?** This is the **AWS Instance Metadata Service (IMDS)** - a special link-local address available only from within EC2 instances. It provides instance information like public/private IPs, instance ID, IAM role credentials, and more. The `169.254.x.x` range is reserved for link-local addresses (not routable, only accessible on the local network segment). AWS "hijacks" this specific address to serve metadata without requiring internet access. Since our private instance has no public IP, the `public-ipv4` endpoint returns empty.
>
> Common IMDS endpoints:
> - `/latest/meta-data/instance-id` - Instance ID
> - `/latest/meta-data/local-ipv4` - Private IP
> - `/latest/meta-data/public-ipv4` - Public IP (if assigned)
> - `/latest/meta-data/iam/security-credentials/` - IAM role credentials

```bash

# Check default route points to bastion
ip route show default
# Output: default via 10.22.6.1 dev ens5 proto dhcp src 10.22.6.x metric 100

# Test ping to bastion private IP
ping -c 3 <BASTION_PRIVATE_IP>
# Output: 3 packets transmitted, 3 received, 0% packet loss

# Test ping to public DNS (via NAT)
ping -c 3 -4 8.8.8.8
# Output: 3 packets transmitted, 3 received, 0% packet loss

# Test internet access (should show bastion's public IP)
curl -4 https://api.ipify.org
# Output: <bastion_public_ip> (same as bastion's public IP)

# Test DNS resolution
nslookup google.com
# Output: Should resolve successfully

# Test HTTP request
curl -4 -I https://www.google.com
# Output: HTTP/1.1 200 OK
```

**✅ All tests should pass**. The private host has internet access via bastion NAT.

**Exit private host**:

```bash
exit
```

## Step 11: View Infrastructure Outputs

Review all infrastructure details.

```bash
cd <project_root>/providers
terraform output
```

**Key outputs**:

```
bastion_public_ip = "X.X.X.X"               # SSH here from your workstation
bastion_private_ip = "10.22.5.x"            # Bastion's internal IP
private_instance_private_ip = "10.22.6.x"   # Private host's internal IP
vpc_id = "vpc-0abc123456789def0"            # VPC identifier
```

**Get specific output**:

```bash
terraform output bastion_public_ip
terraform output -raw bastion_public_ip  # Without quotes
```

## Step 12: Generate Configuration Files

Generate dynamic configuration files with connection details.

```bash
# Return to project root
cd <project_root>

# Generate configuration files
./scripts/generate_config.sh
```

**What this does**:

- Fetches current IP addresses from Terraform outputs
- Generates 4 configuration file formats
- Creates exact SSH commands for current infrastructure
- Updates automatically when infrastructure is redeployed

**Expected output**:

```
Infrastructure Configuration Generator
======================================

Fetching infrastructure details from Terraform...

Infrastructure Details:
  Bastion Public IP:  X.X.X.X
  Bastion Private IP: 10.22.5.x
  Private Host IP:    10.22.6.x
  VPC ID:             vpc-0abc123456789def0

✓ Generated JSON config: <project_root>/config/infrastructure.json
✓ Generated INI config: <project_root>/config/infrastructure.ini
✓ Generated ENV file: <project_root>/config/infrastructure.env
✓ Generated SSH config: <project_root>/config/ssh_config
✓ Generated README: <project_root>/config/README.md
```

**Generated files in `config/`**:

1. **infrastructure.json** - JSON format with all connection details
2. **infrastructure.ini** - INI format for easy parsing
3. **infrastructure.env** - Shell environment variables and aliases
4. **ssh_config** - SSH configuration snippet
5. **README.md** - Usage instructions

### Using the Configuration Files

**Method 1: SSH Config File**

```bash
# Connect to bastion
ssh -F config/ssh_config bastion

# Connect to private host via ProxyJump
ssh -F config/ssh_config private

# Or append to your ~/.ssh/config for permanent use
cat config/ssh_config >> ~/.ssh/config
ssh bastion
ssh private
```

**Method 2: Environment Variables**

```bash
# Source the environment file
source config/infrastructure.env

# Use the convenience aliases
ssh-bastion    # Connect to bastion
ssh-private    # Connect to private host via ProxyJump

# Or use the exported variables
ssh -i $SSH_KEY_PATH $SSH_USER@$BASTION_PUBLIC_IP
```

**Method 3: Connection Scripts (Still Work)**

```bash
# Scripts now read from terraform outputs dynamically
./scripts/connect_bastion.sh
./scripts/connect_private.sh
```

**Why this matters**:

- IP addresses change every time you destroy/rebuild infrastructure
- Configuration files regenerate with new IPs automatically
- No need to manually update connection commands
- Works regardless of how many times you tear down and recreate

**Important**: Run `./scripts/generate_config.sh` after each `terraform apply` to update configuration with new IP addresses.

## Troubleshooting Deployment

### Cannot SSH to Bastion

**Check your IP is allowed**:

```bash
# Get your current public IP
curl -s https://api.ipify.org

# Compare with admin_ip_cidr in terraform.tfvars
cat providers/terraform.tfvars | grep admin_ip_cidr
```

If your IP changed, update `terraform.tfvars` and reapply:

```bash
vim providers/terraform.tfvars  # Update admin_ip_cidr
cd providers
terraform apply
```

**Check security group**:

```bash
# Verify security group allows your IP
terraform show | grep -A 20 'aws_security_group.bastion'
```

### Cannot SSH to Private Host

**Use ProxyJump, not agent forwarding from bastion**:

```bash
# Correct: ProxyJump from workstation
./scripts/connect_private.sh

# Or with agent forwarding
./scripts/connect_bastion.sh
# Then from bastion:
ssh ubuntu@<PRIVATE_HOST_IP>
```

### Private Host Cannot Reach Internet

**Check NAT configuration on bastion**:

```bash
# SSH to bastion
./scripts/connect_bastion.sh

# Check IP forwarding
cat /proc/sys/net/ipv4/ip_forward  # Should be 1

# Check nftables rules
sudo nft list ruleset

# Check nftables service
sudo systemctl status nftables  # Should be active

# Check cloud-init log for errors
sudo tail -50 /var/log/cloud-init-output.log
```

**If NAT still doesn't work, reapply Terraform** (fixes security group):

```bash
cd <project_root>/providers
terraform apply
```

### Terraform Plan Shows Changes When Nothing Changed

This is normal if AWS updated instance metadata. Review the plan carefully. If only metadata changed, it's safe to ignore or apply.

## Next Steps

Now that your infrastructure is deployed and tested:

1. **Save important information**:
   - Bastion public IP
   - VPC ID
   - Instance IDs

2. **Configure SSH config** (optional):
   See [README.md SSH Config section](../README.md#ssh-config-method)

3. **Set up monitoring** (optional):
   See [README.md Monitoring section](../README.md#monitoring-and-logging)

4. **Version control your configuration**:
   See [Git Process Guide](../Notes/TASKS/GIT_PROCESS.md)

## Cost Monitoring

Check estimated costs:

- 2x t3.micro instances: ~$12/month
- 1x Elastic IP (associated): $0/month
- Data transfer: Variable

**Monitor actual costs**:

```bash
# Check AWS Cost Explorer (requires console access)
# Or use AWS CLI:
aws ce get-cost-and-usage \
  --time-period Start=2024-01-01,End=2024-01-31 \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --profile terraform
```

## Summary

You have successfully deployed:

- ✅ VPC with public and private subnets
- ✅ Bastion host with Elastic IP and nftables NAT
- ✅ Private instance with internet access via NAT
- ✅ Security groups restricting access
- ✅ SSH key pair for instance access
- ✅ Tested and validated all components

Your infrastructure is ready for use!
