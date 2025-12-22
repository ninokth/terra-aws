# Tearing Down Infrastructure - Complete Destruction Guide

This guide walks through safely destroying the AWS bastion host infrastructure and cleaning up all resources.

## Overview

The teardown process involves:

1. Verifying what will be destroyed
2. Destroying AWS infrastructure with Terraform
3. Verifying complete removal
4. Cleaning up local files (optional)
5. Removing SSH keys (optional)

## Prerequisites

Before destroying infrastructure:

- ✅ AWS credentials configured (`AWS_PROFILE` and `AWS_REGION` set)
- ✅ Terraform initialized in the `providers/` directory
- ✅ No critical data on instances (all data will be lost)
- ✅ No dependencies on these resources

## ⚠️ Important Warnings

**Before you proceed**:

1. **All data will be permanently deleted**:
   - EC2 instances (bastion and private)
   - Elastic IP address
   - Security group configurations
   - Network routing
   - Everything in the VPC

2. **This action is irreversible**:
   - You cannot recover instances after destruction
   - Any data stored on instances will be lost
   - You'll need to redeploy if you want the infrastructure back

3. **Save important data first**:
   - SSH to instances and backup any important files
   - Export configurations if needed
   - Document any custom changes made post-deployment

## Step 1: Set AWS Credentials

Ensure AWS credentials are set in your current shell session.

```bash
# Set AWS profile and region
export AWS_PROFILE=terraform
export AWS_REGION=eu-north-1
```

**Why we need these**:

- `AWS_PROFILE=terraform`: Tells Terraform which AWS credentials to use for destruction
- `AWS_REGION=eu-north-1`: Tells Terraform which region to destroy resources in

**Verify they're set**:

```bash
echo "Profile: $AWS_PROFILE"
echo "Region: $AWS_REGION"

# Verify AWS access
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

## Step 2: Review Current Infrastructure

Before destroying, review what exists.

```bash
# Navigate to providers directory
cd <project_root>/providers

# List current resources
terraform state list
```

**Expected output**:

```
module.terraform_ws.data.aws_ami.ubuntu
module.terraform_ws.data.aws_caller_identity.current
module.terraform_ws.aws_eip.bastion
module.terraform_ws.aws_instance.bastion
module.terraform_ws.aws_instance.private
module.terraform_ws.aws_internet_gateway.main
module.terraform_ws.aws_key_pair.main
module.terraform_ws.aws_route.private_to_nat
module.terraform_ws.aws_route_table.private
module.terraform_ws.aws_route_table.public
module.terraform_ws.aws_route_table_association.private
module.terraform_ws.aws_route_table_association.public
module.terraform_ws.aws_security_group.bastion
module.terraform_ws.aws_security_group.private
module.terraform_ws.aws_subnet.private
module.terraform_ws.aws_subnet.public
module.terraform_ws.aws_vpc.main
```

**View current outputs**:

```bash
terraform output
```

**Save important IPs** (if you need them for reference):

```bash
echo "Bastion Public IP: $(terraform output -raw bastion_public_ip)"
echo "Bastion Private IP: $(terraform output -raw bastion_private_ip)"
echo "Private Instance IP: $(terraform output -raw private_instance_private_ip)"
echo "VPC ID: $(terraform output -raw vpc_id)"
```

## Step 3: Backup Important Data (If Needed)

If you have any important data on the instances, save it now.

### Backup from Bastion Host

```bash
# SSH to bastion
BASTION_IP=$(terraform output -raw bastion_public_ip)
ssh -i ~/.ssh/id_ed25519 ubuntu@${BASTION_IP}

# Backup any important files
# Example:
tar -czf backup.tar.gz /path/to/important/data

# Exit bastion
exit

# Copy backup to workstation (if needed)
scp -i ~/.ssh/id_ed25519 ubuntu@${BASTION_IP}:backup.tar.gz ~/backups/
```

### Backup from Private Host

```bash
# SSH to private host via ProxyJump
BASTION_IP=$(terraform output -raw bastion_public_ip)
PRIVATE_IP=$(terraform output -raw private_instance_private_ip)
ssh -J ubuntu@${BASTION_IP} -i ~/.ssh/id_ed25519 ubuntu@${PRIVATE_IP}

# Backup any important files
# Exit private host
exit
```

## Step 4: Plan Destruction

Preview what will be destroyed before actually doing it.

```bash
# Generate destruction plan
terraform plan -destroy
```

**What this does**:

- Shows all resources that will be destroyed
- Validates the destruction plan
- Does NOT actually destroy anything yet

**Expected output** (abbreviated):

```
Terraform will perform the following actions:

  # module.terraform_ws.aws_eip.bastion will be destroyed
  - resource "aws_eip" "bastion" {
      - allocation_id        = "eipalloc-0abc123..." -> null
      - domain               = "vpc" -> null
      - instance             = "i-0abc123def456789" -> null
      - public_ip            = "X.X.X.X" -> null
      ...
    }

  # module.terraform_ws.aws_instance.bastion will be destroyed
  - resource "aws_instance" "bastion" {
      - ami                          = "ami-073130f74f5ffb161" -> null
      - instance_type                = "t3.micro" -> null
      ...
    }

  # ... (all other resources)

Plan: 0 to add, 0 to change, 17 to destroy.
```

**Review carefully**:

- **0 to add**: Nothing will be created
- **0 to change**: Nothing will be modified
- **17 to destroy**: All infrastructure will be deleted

## Step 5: Destroy Infrastructure

Destroy all AWS resources.

### Option A: Interactive Destruction (Recommended)

```bash
# Destroy with confirmation prompt
terraform destroy
```

Terraform will show the plan and ask for confirmation:

```
Do you really want to destroy all resources?
  Terraform will destroy all your managed infrastructure, as shown above.
  There is no undo. Only 'yes' will be accepted to confirm.

  Enter a value:
```

**Type `yes` and press Enter to confirm destruction**.

### Option B: Automatic Destruction (No Prompt)

```bash
# Destroy without confirmation (use with caution!)
terraform destroy -auto-approve
```

**⚠️ Warning**: This destroys everything immediately without asking. Use only if you're absolutely sure.

## Step 6: Monitor Destruction Progress

Terraform will destroy resources in reverse dependency order.

**Expected output** (takes 2-3 minutes):

```
module.terraform_ws.aws_route.private_to_nat: Destroying...
module.terraform_ws.aws_route_table_association.private: Destroying...
module.terraform_ws.aws_route_table_association.public: Destroying...
module.terraform_ws.aws_eip.bastion: Destroying...
...
module.terraform_ws.aws_instance.bastion: Destroying... [id=i-0f1391b0c8be9a657]
module.terraform_ws.aws_instance.private: Destroying... [id=i-01aebeb4455aa355c]
module.terraform_ws.aws_instance.bastion: Still destroying... [10s elapsed]
module.terraform_ws.aws_instance.bastion: Destruction complete after 35s
module.terraform_ws.aws_eip.bastion: Destruction complete after 2s
...
module.terraform_ws.aws_subnet.public: Destroying...
module.terraform_ws.aws_subnet.private: Destroying...
module.terraform_ws.aws_subnet.public: Destruction complete after 1s
module.terraform_ws.aws_subnet.private: Destruction complete after 1s
module.terraform_ws.aws_vpc.main: Destroying...
module.terraform_ws.aws_vpc.main: Destruction complete after 1s

Destroy complete! Resources: 17 destroyed.
```

**✅ Success indicators**:

- "Destroy complete! Resources: 17 destroyed."
- No errors
- All resources destroyed

## Step 7: Verify Complete Removal

Confirm all resources are gone.

### Check Terraform State

```bash
# List resources (should be empty)
terraform state list
```

**Expected output**: Empty (no resources)

If resources still appear, they may not have been destroyed. Investigate and run `terraform destroy` again.

### Verify in AWS Console (Optional)

**Check in AWS Console**:

1. **EC2 Dashboard**:
   - Instances: No instances named `tf-demo-bastion` or `tf-demo-private`
   - Elastic IPs: No unassociated EIPs

2. **VPC Dashboard**:
   - VPCs: No VPC named `tf-demo-vpc`
   - Subnets: No subnets named `tf-demo-public-subnet` or `tf-demo-private-subnet`
   - Security Groups: No security groups named `tf-demo-bastion-sg` or `tf-demo-private-sg`

### Verify via AWS CLI

```bash
# Check for VPCs with your name prefix
aws ec2 describe-vpcs \
  --filters "Name=tag:Name,Values=tf-demo-vpc" \
  --profile terraform \
  --region eu-north-1

# Should return empty VPCs list
# Output: {"Vpcs": []}

# Check for instances
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=tf-demo-*" "Name=instance-state-name,Values=running" \
  --profile terraform \
  --region eu-north-1

# Should return empty Reservations list
# Output: {"Reservations": []}
```

## Step 8: Clean Up Local Files (Optional)

Remove Terraform state and lock files from your workstation.

### Remove Terraform Working Directory

```bash
cd <project_root>/providers

# Remove Terraform state and working files
rm -rf .terraform/
rm -f .terraform.lock.hcl
rm -f terraform.tfstate
rm -f terraform.tfstate.backup
```

**What these files are**:

- `.terraform/`: Downloaded provider plugins and modules
- `.terraform.lock.hcl`: Provider version lock file
- `terraform.tfstate`: Current infrastructure state (now empty)
- `terraform.tfstate.backup`: Previous state backup

**⚠️ Warning**: Only remove these if you're completely done. You'll need to `terraform init` again to redeploy.

### Keep Configuration Files

**Do NOT delete** these files (you may need them to redeploy):

- `main.tf`, `variables.tf`, `outputs.tf`, `versions.tf`
- `terraform.tfvars` (contains your configuration)
- `terraform.tfvars.example`

## Step 9: Remove SSH Keys (Optional)

If you no longer need the SSH keys, remove them.

```bash
cd <project_root>

# Run cleanup script
./scripts/cleanup_ssh_key.sh
```

The script will ask for confirmation:

```
SSH Key Cleanup Script
======================

WARNING: This will delete the following files:
  - ~/.ssh/id_ed25519 (private key)
  - ~/.ssh/id_ed25519.pub (public key)

Are you sure you want to delete these keys? (yes/no):
```

**Type `yes` to confirm deletion**.

**Expected output**:

```
✓ Removed private key: ~/.ssh/id_ed25519
✓ Removed public key: ~/.ssh/id_ed25519.pub

✓ SSH keys cleaned up successfully
```

**⚠️ Warning**: If you use these SSH keys for other purposes, do NOT delete them. The cleanup script removes the keys completely.

## Step 10: Verify Cost Savings

After destruction, verify you're no longer being charged.

### Check AWS Bill

```bash
# Check current month costs
aws ce get-cost-and-usage \
  --time-period Start=$(date +%Y-%m-01),End=$(date +%Y-%m-%d) \
  --granularity DAILY \
  --metrics BlendedCost \
  --group-by Type=SERVICE \
  --profile terraform

# Or check in AWS Console:
# Billing Dashboard → Bills
```

**Expected**: No charges for EC2, VPC, or data transfer after instances are terminated.

## Troubleshooting Destruction

### Destroy Fails with Dependency Errors

If destruction fails due to dependencies:

```bash
# Force destroy (use with caution)
terraform destroy -auto-approve

# Or target specific resources
terraform destroy -target=module.terraform_ws.aws_instance.bastion
terraform destroy -target=module.terraform_ws.aws_instance.private
```

### Resources Still Exist After Destroy

**Manually check and remove**:

```bash
# List all resources
aws ec2 describe-instances --profile terraform --region eu-north-1
aws ec2 describe-vpcs --profile terraform --region eu-north-1

# Terminate instances manually if needed
aws ec2 terminate-instances \
  --instance-ids i-0f1391b0c8be9a657 \
  --profile terraform \
  --region eu-north-1

# Delete VPC manually (after all resources are removed)
aws ec2 delete-vpc \
  --vpc-id vpc-0ac32544248aa085f \
  --profile terraform \
  --region eu-north-1
```

### Cannot Destroy VPC

VPCs cannot be deleted while they contain resources. Common blockers:

- ENIs (Elastic Network Interfaces) still attached
- Internet Gateway still attached
- Subnets still exist
- Security groups still referenced

**Fix**:

```bash
# Refresh Terraform state
terraform refresh

# Try destroy again
terraform destroy
```

### Terraform State Out of Sync

If state is corrupted or out of sync:

```bash
# Remove from state (DANGEROUS - only if resource is manually deleted)
terraform state rm module.terraform_ws.aws_instance.bastion

# Or refresh state
terraform refresh

# Then destroy
terraform destroy
```

## Partial Destruction (Advanced)

If you only want to destroy specific resources:

```bash
# Destroy only the private instance
terraform destroy -target=module.terraform_ws.aws_instance.private

# Destroy only the bastion instance
terraform destroy -target=module.terraform_ws.aws_instance.bastion

# Destroy only security groups
terraform destroy -target=module.terraform_ws.aws_security_group.bastion
terraform destroy -target=module.terraform_ws.aws_security_group.private
```

**⚠️ Warning**: Partial destruction can leave infrastructure in an inconsistent state. Only use this if you know what you're doing.

## Redeploying After Destruction

To redeploy the infrastructure:

1. Keep your `terraform.tfvars` configuration
2. Keep your SSH keys (or regenerate with `./scripts/setup_ssh_key.sh`)
3. Ensure AWS credentials are still set
4. Run:

```bash
cd <project_root>/providers
terraform init
terraform apply
```

See [Building Infrastructure Guide](building-infrastructure.md) for full deployment instructions.

## Complete Cleanup Checklist

After destruction, verify:

- ✅ All AWS resources destroyed (17 resources)
- ✅ Terraform state empty (`terraform state list` returns nothing)
- ✅ No running EC2 instances in AWS Console
- ✅ No VPCs with your name prefix
- ✅ No Elastic IPs (unassociated)
- ✅ Local `.terraform/` directory removed (optional)
- ✅ SSH keys removed (optional)
- ✅ AWS bill shows no charges for destroyed resources

## Summary

You have successfully destroyed:

- ✅ 2x EC2 instances (bastion and private)
- ✅ 1x Elastic IP
- ✅ 2x Security groups
- ✅ 1x VPC with subnets and routing
- ✅ 1x Internet Gateway
- ✅ 1x SSH key pair (from AWS, local keys optional)
- ✅ All associated network resources

**Cost impact**: You should see zero charges for these resources starting from the termination time.

**To redeploy**: Follow the [Building Infrastructure Guide](building-infrastructure.md).
