# AWS Bastion Host Infrastructure with Terraform

A production-ready Terraform implementation of a secure bastion host pattern with NAT functionality on AWS. This infrastructure provides a hardened entry point for accessing private resources while maintaining strict security controls.

## Architecture Overview

```
Internet
    |
    v
[Internet Gateway]
    |
    +-- VPC (10.22.0.0/16) -------------------------+
    |                                                |
    +-- Public Subnet (10.22.5.0/24) --------+      |
    |   |                                     |      |
    |   +-- Bastion Host (pub_host-01)       |      |
    |       - Public IP: <EIP assigned>      |      |
    |       - Private IP: 10.22.5.x          |      |
    |       - SSH: Admin IP only             |      |
    |       - NAT: nftables masquerade       |      |
    |       - Firewall: Accept from private  |      |
    |                                         |      |
    +-- Private Subnet (10.22.6.0/24) -------+      |
        |                                            |
        +-- Private Host (prv_host-01)              |
            - Private IP: 10.22.6.x                 |
            - SSH: Bastion only                     |
            - Internet: Via bastion NAT             |
            - No public IP                          |
            |                                        |
            +---------------------------------------+
```

## Key Features

- **Zero Trust Access**: Bastion SSH restricted to single admin IP (your configured IP/32)
- **Private Isolation**: Private instances have no direct internet access or public IPs
- **NAT Functionality**: Bastion provides internet access for private instances using nftables
- **Modern Cryptography**: Ed25519 SSH keys (quantum-resistant)
- **Infrastructure as Code**: Complete Terraform deployment with modular structure
- **Third-Party Ready**: Clone and deploy with minimal configuration
- **Security Best Practices**: No credentials in code, strict security groups, minimal attack surface

## Infrastructure Components

### Phase 0: Identity Validation
- AWS caller identity check (read-only)

### Phase 1: Network Foundation
- VPC with DNS support (10.22.0.0/16)
- Public subnet (10.22.5.0/24) in eu-north-1a
- Private subnet (10.22.6.0/24) in eu-north-1a
- Internet Gateway for public subnet
- Route tables for public and private subnets

### Phase 2: Security Groups
- **Bastion Security Group**:
  - Ingress: SSH (22) from admin IP only
  - Ingress: All traffic from private subnet (for NAT)
  - Egress: All traffic (for updates and NAT forwarding)
- **Private Security Group**:
  - Ingress: SSH (22) from bastion security group only
  - Egress: All traffic (routed via bastion NAT)

### Phase 3: Compute Prerequisites
- Ed25519 SSH key pair
- Ubuntu 24.04 LTS AMI lookup (latest)

### Phase 4: Bastion Instance
- EC2 instance: t3.micro (pub_host-01)
- Elastic IP for stable public access
- Source/destination check disabled for NAT
- nftables NAT configuration (masquerade)
- IP forwarding enabled

### Phase 5: Private Instance + NAT Routing
- EC2 instance: t3.micro (prv_host-01)
- Default route via bastion's ENI
- Internet access through bastion NAT

## Documentation

Complete setup and usage documentation. Each guide is self-contained with explanations, commands, and expected outputs.

### Start Here

| Document | What You'll Learn |
|----------|-------------------|
| [Hitchhiker's Guide](TERRAFORM_hitchhiker_guide.md) | Conceptual overview of Terraform, IaC principles, project structure, and how all pieces fit together |

### Setup Guides

| Document | What You'll Learn |
|----------|-------------------|
| [Terraform Installation](docs/terraform-installation.md) | Install Terraform with GPG signature verification, understand versioning, verify installation |
| [AWS Account Setup](docs/aws-account-setup.md) | Create IAM user with least-privilege permissions, generate access keys, configure AWS CLI profiles |

### Deployment Guides

| Document | What You'll Learn |
|----------|-------------------|
| [Building Infrastructure](docs/building-infrastructure.md) | Deploy VPC, subnets, bastion host with NAT; understand IP addressing (RFC 1918, AWS reserved IPs); test SSH and NAT connectivity |
| [Tearing Down Infrastructure](docs/tearing-down-infrastructure.md) | Safely destroy all resources, verify cleanup, understand cost implications, troubleshoot destruction issues |
| [Scripts Documentation](scripts/README.md) | Use automation scripts for deployment, testing, and cleanup; integrate with CI/CD pipelines; generate connection configs |

### Reference

| Document | What You'll Learn |
|----------|-------------------|
| [Documentation Index](docs/README.md) | Navigate all documentation, understand reading order |

## Prerequisites

### Required Software

- **Terraform >= 1.5** - [Installation Guide](docs/terraform-installation.md)
- **AWS CLI** - [Setup Guide](docs/aws-account-setup.md)
- **AWS Account** with IAM user configured for Terraform
- **SSH client** (for connecting to instances)

### AWS Credentials Setup

You must configure AWS credentials before deploying. Follow the [AWS Account Setup Guide](docs/aws-account-setup.md) for detailed instructions.

**Quick Setup** (choose ONE method):

**Option A: AWS CLI Profile (Recommended)**

```bash
# Configure AWS profile
aws configure --profile terraform

# Set environment variables
export AWS_PROFILE=terraform
export AWS_REGION=eu-north-1
```

**Option B: Environment Variables**

```bash
export AWS_ACCESS_KEY_ID="YOUR_ACCESS_KEY"
export AWS_SECRET_ACCESS_KEY="YOUR_SECRET_KEY"
export AWS_REGION="eu-north-1"
```

> **Security Note**: Never hardcode credentials in `.tf` files. Terraform state files can leak secrets.

## Quick Start

```bash
# 1. Clone repository
git clone <repository-url>
cd terraform_demo

# 2. Generate SSH keys
./scripts/setup_ssh_key.sh

# 3. Configure variables
cp providers/terraform.tfvars.example providers/terraform.tfvars
# Edit providers/terraform.tfvars and set your admin_ip_cidr

# 4. Set AWS credentials
export AWS_PROFILE=terraform
export AWS_REGION=eu-north-1

# 5. Deploy infrastructure
terraform -chdir=providers init
terraform -chdir=providers apply

# 6. Connect to bastion
./scripts/connect_bastion.sh

# 7. Connect to private host (via ProxyJump)
./scripts/connect_private.sh
```

## Automated Workflow (CI/CD Ready)

For fully automated deployment with validation, use the script-based workflow. All scripts are self-contained with proper exit codes and logging, suitable for CI/CD pipelines.

```bash
# 1. First-time setup (validates environment, creates terraform.tfvars, runs init)
./scripts/first_time_setup.sh

# 2. Deploy infrastructure (applies terraform, waits for instances to be ready)
./scripts/deploy.sh

# 3. Test infrastructure (E2E validation: SSH access, NAT connectivity)
./scripts/test_infrastructure.sh

# 4. Connect to hosts
./scripts/connect_bastion.sh      # SSH to bastion with agent forwarding
./scripts/connect_private.sh      # SSH to private host via ProxyJump

# 5. Generate connection configs (optional - creates SSH config, env files)
./scripts/generate_config.sh

# 6. Destroy infrastructure (destroys resources, verifies cleanup)
./scripts/destroy.sh
```

See [Scripts Documentation](scripts/README.md) for detailed script descriptions and CI/CD integration.

## Directory Structure

```
terraform_demo/
├── TERRAFORM_hitchhiker_guide.md  # Start here - conceptual overview
├── README.md                      # This file - quick start & reference
├── LICENSE                        # MIT License
├── CONTRIBUTING.md                # Contribution guidelines
│
├── providers/                     # ROOT MODULE (run terraform here)
│   ├── main.tf                   # Provider config + module call
│   ├── versions.tf               # Terraform version constraints
│   ├── variables.tf              # Input variable declarations
│   ├── outputs.tf                # Output forwarding from child module
│   ├── terraform.tfvars.example  # Example configuration
│   └── terraform.tfvars          # Your configuration (git-ignored)
│
├── terraform_ws/                  # CHILD MODULE (infrastructure resources)
│   ├── main.tf                   # All infrastructure resources
│   ├── variables.tf              # Module input variables
│   └── outputs.tf                # Module outputs
│
├── docs/                          # Documentation
│   ├── README.md                 # Documentation index
│   ├── terraform-installation.md # Terraform setup guide
│   ├── aws-account-setup.md      # AWS IAM & credentials setup
│   ├── building-infrastructure.md    # Deployment guide
│   └── tearing-down-infrastructure.md # Destruction guide
│
├── scripts/                       # Automation scripts (CI/CD ready)
│   ├── first_time_setup.sh       # Validate config, create tfvars, init
│   ├── deploy.sh                 # Deploy infrastructure
│   ├── test_infrastructure.sh    # E2E connectivity tests
│   ├── destroy.sh                # Destroy and verify cleanup
│   ├── connect_bastion.sh        # SSH to bastion
│   ├── connect_private.sh        # SSH to private host via ProxyJump
│   ├── generate_config.sh        # Generate connection configs
│   ├── setup_ssh_key.sh          # Generate SSH key pair
│   ├── cleanup_ssh_key.sh        # Remove SSH key pair
│   ├── cleanup_artifacts.sh      # Remove temp files (plan, logs)
│   ├── lib/                      # Shared functions library
│   ├── current_state/            # Runtime state (git-ignored)
│   └── README.md                 # Scripts documentation
│
├── config/                        # Generated configs (git-ignored)
│   └── user.conf.example         # User configuration template
│
├── backup/                        # Backup files (git-ignored)
│
└── logs/                          # Script logs (git-ignored)
```

## Configuration

### Required Variables

Edit `providers/terraform.tfvars`:

```hcl
# AWS region
region = "eu-north-1"

# Resource naming prefix
name_prefix = "tf-demo"

# Your public IP address for SSH access (REQUIRED)
# Find your IP: curl -s https://api.ipify.org
admin_ip_cidr = "YOUR.IP.ADDRESS/32"
```

### Optional Variables

```hcl
# Network configuration
vpc_cidr              = "10.22.0.0/16"
public_subnet_cidr    = "10.22.5.0/24"
private_subnet_cidr   = "10.22.6.0/24"
availability_zone     = "eu-north-1a"

# SSH key path
ssh_public_key_path   = "~/.ssh/id_ed25519.pub"

# Instance types
bastion_instance_type = "t3.micro"
private_instance_type = "t3.micro"
```

> **Understanding IP Addresses**: For a detailed explanation of why these specific IP ranges are used (RFC 1918 private addressing, AWS reserved IPs, and best practices), see [Understanding the IP Addresses](docs/building-infrastructure.md#understanding-the-ip-addresses) in the deployment guide.

## Deployment

### Initial Deployment

```bash
# Initialize Terraform
terraform -chdir=providers init

# Review planned changes
terraform -chdir=providers plan

# Apply infrastructure
terraform -chdir=providers apply
```

### View Outputs

```bash
terraform -chdir=providers output
```

Key outputs:
- `bastion_public_ip`: Elastic IP for SSH access
- `bastion_private_ip`: Internal IP in public subnet
- `private_instance_private_ip`: Internal IP in private subnet
- `vpc_id`, `subnet_ids`, `security_group_ids`: Infrastructure identifiers

## SSH Access

### Method 1: Connection Scripts (Recommended)

**Connect to Bastion**
```bash
./scripts/connect_bastion.sh
```
Connects with SSH agent forwarding enabled. From bastion, you can then SSH to private host.

**Connect to Private Host (Direct ProxyJump)**
```bash
./scripts/connect_private.sh
```
Connects directly from your workstation through bastion in one command.

### Method 2: Manual SSH Commands

**Bastion with Agent Forwarding**
```bash
ssh -A -i ~/.ssh/id_ed25519 ubuntu@$(terraform -chdir=providers output -raw bastion_public_ip)
```

**Private Host via ProxyJump**
```bash
ssh -J ubuntu@$(terraform -chdir=providers output -raw bastion_public_ip) \
    -i ~/.ssh/id_ed25519 \
    ubuntu@$(terraform -chdir=providers output -raw private_instance_private_ip)
```

**From Bastion to Private Host**
```bash
# First connect to bastion with agent forwarding (-A flag)
# Then from bastion:
ssh ubuntu@<private-ip>
```

### SSH Config Method

Add to `~/.ssh/config`:

```ssh-config
Host bastion
    HostName <BASTION_PUBLIC_IP>
    User ubuntu
    IdentityFile ~/.ssh/id_ed25519
    ForwardAgent yes

Host private
    HostName <PRIVATE_INSTANCE_IP>
    User ubuntu
    IdentityFile ~/.ssh/id_ed25519
    ProxyJump bastion
```

Then connect with:
```bash
ssh bastion    # Connect to bastion
ssh private    # Connect to private host
```

## Testing

### Test Bastion Access

```bash
# Connect to bastion
./scripts/connect_bastion.sh

# Check hostname
hostname  # Should show: pub_host-01

# Check IP forwarding
cat /proc/sys/net/ipv4/ip_forward  # Should show: 1

# Check nftables NAT rules
sudo nft list ruleset

# Verify internet access
curl -4 https://api.ipify.org  # Should return bastion's public IP
```

### Test Private Host Access and NAT

```bash
# Connect to private host
./scripts/connect_private.sh

# Check hostname
hostname  # Should show: prv_host-01

# Verify no public IP
curl -s --max-time 5 http://169.254.169.254/latest/meta-data/public-ipv4
# Should timeout (no public IP assigned)

# Test internet access via bastion NAT
ping -c 3 8.8.8.8

# Check public IP (should be bastion's IP)
curl -4 https://api.ipify.org  # Should return bastion's public IP

# Test DNS resolution
nslookup google.com

# Check default route
ip route show default  # Should show route via bastion
```

## Teardown

### Full Infrastructure Removal

```bash
# 1. Destroy all AWS resources
terraform -chdir=providers destroy

# 2. (Optional) Remove SSH keys
./scripts/cleanup_ssh_key.sh
```

### Partial Teardown

```bash
# Destroy specific resources
terraform -chdir=providers destroy -target=module.terraform_ws.aws_instance.private
```

## Security Considerations

### Network Security
- Bastion host is the only resource with a public IP
- Private instances are completely isolated from direct internet access
- Security groups enforce strict ingress/egress rules
- No public-facing services on private instances

### SSH Security
- Ed25519 keys (modern, quantum-resistant algorithm)
- Bastion access restricted to single admin IP
- Private instances accessible only from bastion
- No password authentication (key-based only)

### NAT Security
- nftables provides stateful firewall with connection tracking
- Only private subnet (10.22.6.0/24) can route through NAT
- Bastion security group explicitly allows traffic from private subnet
- Source/destination checks disabled only on bastion (required for NAT)

### Operational Security
- No credentials stored in Terraform code
- SSH keys generated locally, not by Terraform
- Terraform state contains sensitive data - store remotely (S3 + DynamoDB) in production
- Regular security updates via user-data scripts

## Troubleshooting

### Cannot SSH to Bastion

**Check security group and admin IP**
```bash
# Verify your current public IP
curl -s https://api.ipify.org

# Update admin_ip_cidr in providers/terraform.tfvars if changed
admin_ip_cidr = "NEW.IP.ADDRESS/32"

# Apply changes
terraform -chdir=providers apply
```

### Cannot SSH from Bastion to Private Host

**Use SSH agent forwarding or ProxyJump**
```bash
# Exit bastion and reconnect with agent forwarding
./scripts/connect_bastion.sh

# Or use ProxyJump directly
./scripts/connect_private.sh
```

### Private Host Cannot Reach Internet

**Check bastion security group allows traffic from private subnet**
```bash
# Should show ingress rule from 10.22.6.0/24
terraform -chdir=providers show | grep -A 10 'aws_security_group.bastion'
```

**Verify NAT configuration on bastion**
```bash
# SSH to bastion
./scripts/connect_bastion.sh

# Check IP forwarding
cat /proc/sys/net/ipv4/ip_forward  # Should be 1

# Check nftables NAT rules
sudo nft list ruleset | grep -A 5 'chain postrouting'

# Check nftables service
sudo systemctl status nftables
```

**Test connectivity from private host**
```bash
# Connect to private host
./scripts/connect_private.sh

# Check default route points to bastion
ip route show default

# Test ping to bastion
ping -c 3 <BASTION_PRIVATE_IP>

# Test ping to public DNS
ping -c 3 -4 8.8.8.8

# Test HTTP
curl -4 -I https://www.google.com
```

### IPv6 Connection Issues

The infrastructure is IPv4-only. Force IPv4:
```bash
# From private host, use -4 flag
curl -4 https://api.ipify.org
ping -4 8.8.8.8
```

## Production Recommendations

### Remote State Management

Use S3 backend for team collaboration:

```hcl
# providers/backend.tf
terraform {
  backend "s3" {
    bucket         = "your-terraform-state-bucket"
    key            = "bastion-infrastructure/terraform.tfstate"
    region         = "eu-north-1"
    encrypt        = true
    dynamodb_table = "terraform-state-locks"
  }
}
```

### High Availability

- Deploy bastion instances in multiple AZs with Auto Scaling Group
- Use Network Load Balancer for bastion access
- Configure CloudWatch alarms for bastion health
- Implement automated backups

### Monitoring and Logging

- Enable VPC Flow Logs
- Configure CloudWatch logging for SSH sessions
- Set up AWS Systems Manager Session Manager as SSH alternative
- Monitor bastion NAT throughput and errors

### Hardening

- Implement fail2ban on bastion host
- Enable automatic security updates
- Use AWS Systems Manager for patch management
- Implement SSH session recording
- Configure MFA for SSH access
- Regularly rotate SSH keys

## Cost Estimate

Approximate monthly costs (eu-north-1 region):
- 2x t3.micro instances: ~$12
- 1x Elastic IP (associated): $0
- Data transfer: Variable (first 1GB free)
- NAT traffic: Included (no NAT Gateway charges)

**Estimated total: ~$12-15/month**

## License

This infrastructure code is provided as-is for educational and production use.

## Contributing

Improvements and bug fixes are welcome. Please ensure:
- All phases are tested with provision/deprovision cycles
- Security best practices are maintained
- Documentation is updated

## Support

For issues and questions, please check:
1. This README troubleshooting section
2. Terraform plan/apply output for specific errors
3. AWS CloudWatch logs for instance user-data execution
4. `/var/log/cloud-init-output.log` on instances for startup issues

## References

### AWS Documentation

| Topic | Link |
|-------|------|
| VPC Overview | [What is Amazon VPC?](https://docs.aws.amazon.com/vpc/latest/userguide/what-is-amazon-vpc.html) |
| Security Groups | [Control traffic with security groups](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-security-groups.html) |
| Network ACLs | [Control traffic with network ACLs](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-network-acls.html) |
| Security Groups vs NACLs | [Compare security groups and network ACLs](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-security-groups.html#vpc-security-groups-vs-network-acls) |
| NAT Instances | [NAT instances](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_NAT_Instance.html) |
| Elastic IPs | [Elastic IP addresses](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/elastic-ip-addresses-eip.html) |
| EC2 Instance Metadata | [Instance metadata and user data](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-instance-metadata.html) |
| IAM Best Practices | [Security best practices in IAM](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html) |

### Terraform Documentation

| Topic | Link |
|-------|------|
| AWS Provider | [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs) |
| aws_vpc | [VPC Resource](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc) |
| aws_subnet | [Subnet Resource](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) |
| aws_security_group | [Security Group Resource](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) |
| aws_instance | [EC2 Instance Resource](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance) |
| aws_eip | [Elastic IP Resource](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip) |
| aws_route_table | [Route Table Resource](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) |
| Backend Configuration | [Backend Configuration](https://developer.hashicorp.com/terraform/language/backend) |
| State Management | [State](https://developer.hashicorp.com/terraform/language/state) |

### Additional Resources

| Topic | Link |
|-------|------|
| RFC 1918 (Private IPs) | [Address Allocation for Private Internets](https://datatracker.ietf.org/doc/html/rfc1918) |
| nftables | [nftables wiki](https://wiki.nftables.org/) |
| SSH ProxyJump | [OpenSSH ProxyJump](https://man.openbsd.org/ssh_config#ProxyJump) |
| Ed25519 Keys | [Ed25519: high-speed high-security signatures](https://ed25519.cr.yp.to/) |
