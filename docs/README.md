# Documentation Index

Complete documentation for the AWS Bastion Host Infrastructure with Terraform.

## Why This Repository Exists

Most Terraform tutorials teach you commands. They show you `terraform apply` and leave you hoping it works. When something breaks—and it will—you're left guessing.

This repository takes a different approach. **The goal is not just to deploy infrastructure, but to understand what you're doing and why it works.**

We built a real AWS bastion host infrastructure as a learning vehicle. It's complex enough to demonstrate real patterns (VPCs, subnets, security groups, NAT routing, multi-instance architectures) but simple enough to understand completely. Every piece is documented not just with "how" but with "why."

### The Learning Journey

The documentation follows a deliberate progression:

1. **Understand the mental model first** — Before touching any commands, read the [Hitchhiker's Guide to Terraform](TERRAFORM_hitchhiker_guide.md). It explains how Terraform actually thinks: the three worlds it manages, why declarative matters, how graphs drive execution. This foundation makes everything else predictable instead of magical.

2. **Install the tools properly** — The [Terraform Installation](terraform-installation.md) guide covers secure installation with signature verification. The [AWS Account Setup](aws-account-setup.md) guide walks through creating proper IAM users with least-privilege permissions. These aren't optional steps—they're foundations.

3. **Deploy real infrastructure** — With understanding and tools in place, [Building Infrastructure](building-infrastructure.md) guides you through actual deployment. You'll see `terraform plan` output and understand what it means. You'll watch resources create and know why they're created in that order.

4. **Clean up properly** — [Tearing Down Infrastructure](tearing-down-infrastructure.md) ensures you can destroy what you've built without leaving orphaned resources or surprise bills.

### Why Each Document Exists

| Document | Purpose |
|----------|---------|
| [TERRAFORM_hitchhiker_guide.md](TERRAFORM_hitchhiker_guide.md) | The conceptual foundation. Read this first to understand Terraform's mental model—idempotency, convergence, state, graphs. Makes all other documentation comprehensible. |
| [terraform-installation.md](terraform-installation.md) | Secure Terraform setup. Covers GPG verification and proper installation—not just "download and run." |
| [aws-account-setup.md](aws-account-setup.md) | AWS credential setup done right. Creates dedicated IAM user with proper permissions instead of using root credentials. |
| [building-infrastructure.md](building-infrastructure.md) | The actual deployment. Step-by-step with explanations of what each phase creates and why. |
| [tearing-down-infrastructure.md](tearing-down-infrastructure.md) | Clean destruction. Ensures complete teardown without orphaned resources. |
| [../scripts/README.md](../scripts/README.md) | Helper script documentation. Explains the automation that makes deployment and testing repeatable. |

### Scripts vs Manual Execution

This repository includes comprehensive helper scripts (`scripts/`) that automate the entire workflow—setup, deployment, testing, and teardown. You can get everything working by running a few commands.

**But we encourage you to do it manually first.**

The scripts are documented. Read them. Understand what each command does. Then follow the step-by-step guides and run the Terraform commands yourself. Watch what happens. Read the output.

Once you understand the process, use the scripts for convenience. But don't skip the learning—the scripts will always be there, but the understanding won't come from running them blindly.

### The Philosophy

**Understanding beats memorization.** If you understand that Terraform builds a dependency graph and executes in topological order, you'll never be confused about why one resource is created before another. If you understand that state is Terraform's memory of what it's managing, you'll never accidentally orphan resources.

This repository is designed so that when you finish, you don't just have working infrastructure—you have the mental model to build, debug, and extend any Terraform project confidently.

---

## Getting Started

### 1. Prerequisites Setup

Before deploying this infrastructure, complete these setup steps:

1. **[Terraform Installation](terraform-installation.md)**
   - Install Terraform 1.5+ with GPG verification
   - Package manager installation (Ubuntu/Debian, macOS)
   - Manual binary installation with signature verification
   - Version verification

2. **[AWS Account Setup](aws-account-setup.md)**
   - Create dedicated IAM user for Terraform
   - Configure group-based permissions
   - Generate access keys
   - Install and configure AWS CLI
   - Validate authentication with test deployment

### 2. Deployment

Once prerequisites are complete, deploy the infrastructure:

- **[Building Infrastructure](building-infrastructure.md)** - Complete step-by-step deployment guide with testing
- **[Main README](../README.md)** - Infrastructure overview and quick start
- **[Scripts Documentation](../scripts/README.md)** - Helper scripts for deployment and SSH connections

### 3. Teardown

When you're done with the infrastructure:

- **[Tearing Down Infrastructure](tearing-down-infrastructure.md)** - Complete destruction guide with verification

## Documentation Structure

```text
docs/
├── README.md                       # This file - documentation index
├── terraform-installation.md       # Terraform setup guide
├── aws-account-setup.md            # AWS IAM and credentials setup
├── building-infrastructure.md      # Step-by-step deployment guide
├── tearing-down-infrastructure.md  # Step-by-step destruction guide
└── TERRAFORM_hitchhiker_guide.md   # Deep dive into Terraform concepts

scripts/
└── README.md                       # Helper scripts documentation
```

## Quick Navigation

### Installation Guides

- [Install Terraform](terraform-installation.md#quick-installation-package-manager)
- [Install AWS CLI](aws-account-setup.md#32-install-aws-cli-if-needed)
- [Verify Installation](terraform-installation.md#verify-installation)

### Configuration Guides

- [Create IAM User](aws-account-setup.md#1-create-iam-user-for-terraform)
- [Configure AWS Credentials](aws-account-setup.md#3-configure-aws-cli)
- [Configure Terraform Variables](../README.md#configuration)

### Deployment Guides

- [Building Infrastructure](building-infrastructure.md) - Complete deployment with testing
- [Quick Start](../README.md#quick-start) - Fast deployment overview
- [Full Deployment Workflow](../scripts/README.md#full-deployment) - Scripts-based deployment
- [SSH Connection Methods](../README.md#ssh-access) - Multiple SSH access patterns
- [Tearing Down Infrastructure](tearing-down-infrastructure.md) - Safe destruction guide

### Troubleshooting

- [Terraform Installation Issues](terraform-installation.md#troubleshooting)
- [AWS Authentication Issues](aws-account-setup.md#troubleshooting)
- [Infrastructure Issues](../README.md#troubleshooting)

## Conceptual Guides

- **[The Hitchhiker's Guide to Terraform](TERRAFORM_hitchhiker_guide.md)** - Deep dive into how Terraform actually works: the three worlds (configuration, state, reality), graph theory perspective, power features, and mental models that make Terraform predictable.

## Architecture Documentation

### Infrastructure Components

Detailed breakdown in the [Main README](../README.md#infrastructure-components):

1. Identity Validation
2. Network Foundation (VPC, subnets, IGW, route tables)
3. Security Groups
4. Compute Prerequisites (SSH keys, AMI)
5. Bastion Instance with NAT
6. Private Instance with NAT routing

### Security

Security features documented in the [Main README](../README.md#security-considerations):

- Network Security
- SSH Security
- NAT Security
- Operational Security

## Helper Scripts

All scripts documented in [scripts/README.md](../scripts/README.md):

- `first_time_setup.sh` - Validate config, create terraform.tfvars, run terraform init
- `deploy.sh` - Deploy infrastructure, wait for instances to be ready
- `test_infrastructure.sh` - Test SSH and NAT connectivity
- `destroy.sh` - Destroy infrastructure, verify cleanup
- `connect_bastion.sh` - SSH to bastion with agent forwarding
- `connect_private.sh` - SSH to private host via ProxyJump
- `generate_config.sh` - Generate config files for integration
- `setup_ssh_key.sh` - Generate Ed25519 SSH keys
- `cleanup_ssh_key.sh` - Remove SSH keys

## Production Recommendations

- [Remote State Management](../README.md#remote-state-management)
- [High Availability](../README.md#high-availability)
- [Monitoring and Logging](../README.md#monitoring-and-logging)
- [Security Hardening](../README.md#hardening)

## Support

For issues and questions:

1. Check the troubleshooting sections in each guide
2. Review Terraform plan/apply output for specific errors
3. Check AWS CloudWatch logs for instance user-data execution
4. Review `/var/log/cloud-init-output.log` on instances for startup issues

## Contributing

When contributing documentation:

- Keep guides focused and task-oriented
- Include complete examples with expected output
- Add troubleshooting sections for common issues
- Update this index when adding new documentation
