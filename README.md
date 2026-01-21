# Terraform AWS Bastion + NAT (Dev/Prod)

A production-ready Terraform implementation of a secure bastion host pattern with NAT functionality on AWS. It is structured around separate `environments/dev` and `environments/prod` roots to compare bastion-based NAT vs NAT Gateway. This project is used to validate Terraform workflow and modular design in a real AWS layout, with tight network controls and minimal exposure of private resources.

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

Note: This is a single-AZ deployment by default (eu-north-1a). For production workloads requiring high availability, deploy across multiple AZs.

## Environments

- `environments/dev` uses a bastion host as a NAT instance (nftables).
- `environments/prod` uses an AWS NAT Gateway for production-grade egress.

Each environment has its own state file to avoid cross-environment changes.

## Why Bastion-as-NAT (not NAT Gateway)?

Development uses a bastion host as a NAT instance via nftables. This is a deliberate choice to highlight the tradeoffs between dev and prod environments.

| Aspect | Bastion-as-NAT (dev) | AWS NAT Gateway (prod) |
|--------|----------------------|------------------------|
| Throughput | Limited by instance type | High, managed throughput |
| Availability | Single point of failure | Managed, per-AZ redundancy |
| Maintenance | You manage OS, nftables | Fully managed |
| Learning value | High - understand NAT internals | Lower - "it just works" |

For production workloads with high availability requirements, use NAT Gateway (prod) or multiple AZs.

## Key Features

- Zero trust access: Bastion SSH restricted to a single admin IP (/32)
- Private isolation: Private instances have no direct internet access or public IPs
- NAT functionality: Egress via nftables (dev) or NAT Gateway (prod)
- Modern cryptography: Ed25519 SSH keys
- Infrastructure as code: Modular Terraform structure
- Security best practices: No credentials in code, strict security groups

## Infrastructure Components

Terraform builds infrastructure in dependency order. Components grouped by function:

1. Identity validation (AWS caller identity check)
2. Network foundation (VPC, subnets, IGW, route tables)
3. Security groups (bastion and private host rules)
4. Compute prerequisites (SSH key, AMI lookup)
5. Bastion instance (EIP, IP forwarding, nftables)
6. Private instance + NAT routing
7. IAM + logging (roles, flow logs, CloudWatch) where enabled

## Repository Layout (Current)

```
terraform-aws/
├── environments/               # Root modules (run terraform here)
│   ├── dev/
│   └── prod/
├── terraform_ws/               # Workspace module (wires shared modules)
├── modules/                    # Reusable infrastructure modules
│   ├── bastion/
│   ├── iam/
│   ├── nat-gateway/
│   ├── private-instance/
│   ├── security-groups/
│   ├── ssh-key/
│   └── vpc/
├── CONTRIBUTING.md
├── LICENSE
└── .pre-commit-config.yaml     # Pre-commit hooks
```

## Prerequisites (Minimum)

- Terraform CLI (1.5+ recommended)
- AWS CLI (`aws`)
- `ssh-keygen`
- `curl`
- AWS account + credentials configured locally

Optional but recommended:
- `pre-commit` (see Pre-Commit section)
- `tflint`, `terraform-docs`, `checkov` if you want the full hook set

## AWS Credentials Setup

### Option A: AWS CLI Profile (Recommended)

```bash
aws configure --profile terraform
export AWS_PROFILE="terraform"
export AWS_REGION="eu-north-1"
# Read-only check to confirm credentials and account
aws sts get-caller-identity
```

### Option B: Environment Variables

```bash
export AWS_ACCESS_KEY_ID="YOUR_ACCESS_KEY"  # pragma: allowlist secret
export AWS_SECRET_ACCESS_KEY="YOUR_SECRET_KEY"  # pragma: allowlist secret
export AWS_REGION="eu-north-1"
```

Security note: Never hardcode credentials in `.tf` files. Terraform state can contain sensitive data.

## Quick Start (Manual)

### 1) Choose Environment

- Dev: `environments/dev`
- Prod: `environments/prod`

### 2) Set AWS Credentials

```bash
export AWS_PROFILE="terraform"
export AWS_REGION="eu-north-1"
# Read-only check to confirm credentials and account
aws sts get-caller-identity
```

### 3) Detect Public IP (for SSH ingress)

```bash
curl -s -w '\n' https://api.ipify.org
```

Use the result as `admin_ip_cidr` with `/32`.

### 4) Ensure SSH Key Exists

```bash
ls -la ~/.ssh/id_ed25519*
# Only generate if the key does not already exist to avoid overwriting user keys
test -f ~/.ssh/id_ed25519 || ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N "" -C "tf-bastion"
```

### 5) Create `terraform.tfvars`

```bash
cd environments/dev   # or environments/prod
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and set at minimum:

```hcl
admin_ip_cidr = "YOUR.IP.ADDRESS/32"
```

To find your public IP:

```bash
curl -s -w '\n' https://api.ipify.org
```

### 6) Init, Validate, Plan, Apply

```bash
terraform init
terraform validate
terraform plan
terraform apply
```

### 7) Outputs

```bash
terraform output
```

Common outputs include bastion/public IPs, private instance IP, and NAT mode.

## Teardown

Run from the same environment directory:

```bash
terraform destroy
```

Note: This only destroys resources in the selected environment (dev or prod). Review the plan before confirming.

## Pre-Commit

This repo uses pre-commit hooks for formatting, validation, linting, docs, and secret scanning.

```bash
pre-commit install
pre-commit run --all-files
```

Note: The full hook set requires `tflint`, `terraform-docs`, and `checkov`.
Repo configs: `.pre-commit-config.yaml`, `.tflint.hcl`, `.terraform-docs.yml`, `.checkov.yaml`.

Additional notes from hook configs:
- `terraform_docs` injects module docs between `<!-- BEGIN_TF_DOCS -->` and `<!-- END_TF_DOCS -->` in module READMEs.
- `terraform_tflint` uses `.tflint.hcl`; install AWS rules with `tflint --init` before running `pre-commit run`.
- `terraform_checkov` runs with compact output and skips checks `CKV2_AWS_5` and `CKV_AWS_382` per `.checkov.yaml`.

## Configuration

Required (both environments):

```hcl
admin_ip_cidr = "YOUR.IP.ADDRESS/32"
```

Optional (defaults differ per environment):

```hcl
# region                = "eu-north-1"
# availability_zone     = "eu-north-1a"
# name_prefix           = "tf-dev" or "tf-prod"
# vpc_cidr              = "10.22.0.0/16" (dev) or "10.23.0.0/16" (prod)
# public_subnet_cidr    = "10.22.5.0/24" (dev) or "10.23.5.0/24" (prod)
# private_subnet_cidr   = "10.22.6.0/24" (dev) or "10.23.6.0/24" (prod)
# bastion_instance_type = "t3.micro"
# private_instance_type = "t3.micro"
# ssh_public_key_path   = "~/.ssh/id_ed25519.pub"
```

See `environments/dev/terraform.tfvars.example` or `environments/prod/terraform.tfvars.example` for defaults.

## Deployment

Run in the environment directory you want to manage:

```bash
cd environments/dev   # or environments/prod
terraform init
terraform plan
terraform apply
```

View outputs:

```bash
terraform output
```

## Teardown

To destroy all resources:

```bash
terraform destroy
```

## SSH Access

```bash
BASTION_IP=$(terraform output -raw bastion_public_ip)
PRIVATE_IP=$(terraform output -raw private_instance_private_ip)

# Bastion (agent forwarding recommended)
ssh -A -i ~/.ssh/id_ed25519 ubuntu@"$BASTION_IP"

# Private host via bastion (ProxyJump)
ssh -J ubuntu@"$BASTION_IP" -i ~/.ssh/id_ed25519 ubuntu@"$PRIVATE_IP"
```

ProxyJump uses your local key without copying it to the bastion host.

## Testing

```bash
BASTION_IP=$(terraform output -raw bastion_public_ip)
PRIVATE_IP=$(terraform output -raw private_instance_private_ip)
NAT_MODE=$(terraform output -raw nat_mode)

# Bastion SSH test
ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no ubuntu@"$BASTION_IP" "hostname"

# Private SSH test via bastion
ssh -o StrictHostKeyChecking=no -J ubuntu@"$BASTION_IP" ubuntu@"$PRIVATE_IP" "hostname"

# NAT egress check (dev should match bastion IP, prod should match NAT Gateway IP)
ssh -J ubuntu@"$BASTION_IP" ubuntu@"$PRIVATE_IP" "curl -s -w '\n' https://api.ipify.org"

echo "NAT mode: $NAT_MODE"
```

## Troubleshooting

> **Note:** Ensure you are in the correct environment directory (`environments/dev` or `environments/prod`) before running these commands.

### Cannot SSH to Bastion

```bash
curl -s -w '\n' https://api.ipify.org
```

Update `admin_ip_cidr` in your `terraform.tfvars`, then apply:

```bash
terraform apply
```

### Cannot SSH to Private Host

Use ProxyJump from your local machine (the private key is local):

```bash
BASTION_IP=$(terraform output -raw bastion_public_ip)
PRIVATE_IP=$(terraform output -raw private_instance_private_ip)
ssh -J ubuntu@"$BASTION_IP" -i ~/.ssh/id_ed25519 ubuntu@"$PRIVATE_IP"
```

### Private Host Cannot Reach Internet

```bash
BASTION_IP=$(terraform output -raw bastion_public_ip)
PRIVATE_IP=$(terraform output -raw private_instance_private_ip)
ssh -J ubuntu@"$BASTION_IP" ubuntu@"$PRIVATE_IP" "ip route show default"
```

## Security Notes

- Do not commit `terraform.tfvars`.
- Keep SSH keys local and never add them to the repo.
- Restrict `admin_ip_cidr` to your current public IP.

## License

This infrastructure code is provided as-is for educational and production use. See `LICENSE`.

## Contributing

Improvements and bug fixes are welcome. Please ensure:

- Changes are tested with provision/deprovision cycles
- Security best practices are maintained
- Documentation is updated
