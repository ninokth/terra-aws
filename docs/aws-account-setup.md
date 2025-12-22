# AWS Account Setup for Terraform

This guide walks through setting up AWS IAM credentials for Terraform following security best practices.

## Overview

Terraform requires AWS credentials to manage infrastructure. This guide covers:

1. Creating a dedicated IAM user for Terraform
2. Setting up group-based permissions
3. Configuring AWS CLI with the credentials
4. Validating the setup with a read-only test

## Prerequisites

- AWS account with administrative access
- AWS CLI installed on your workstation
- Terraform installed (see [Terraform Installation Guide](terraform-installation.md))

## 1. Create IAM User for Terraform

### 1.1 Create User

1. Log into AWS Console
2. Navigate to **IAM → Users → Create user**
3. Configure user details:
   - **User name**: `terraform-admin`
   - **Console access**: ❌ **UNCHECKED** (programmatic access only)
4. Click **Next**

### 1.2 Set Permissions via Group

Follow AWS best practice by using group-based permissions:

1. Choose: **Add user to group**
2. Click **Create group**

### 1.3 Create IAM Group

#### Group Details

- **Group name**: `terraform-admins`

#### Attach Permissions

For this infrastructure project, attach:

- **AdministratorAccess**

> **Note**: This provides full AWS access required for creating VPCs, EC2 instances, security groups, etc. In production, use more restrictive policies.

Click **Create user group**

### 1.4 Add User to Group

1. Back on the **Set permissions** screen
2. Select: ☑️ **terraform-admins**
3. Click **Next**

### 1.5 Skip Permissions Boundary

- Do not set a permissions boundary (for demo purposes)
- Click **Next**

### 1.6 Review and Create

Verify the configuration:

- **User name**: `terraform-admin`
- **Console access**: ❌ disabled
- **Group**: `terraform-admins`
- **Effective permissions**: AdministratorAccess

Click **Create user**

## 2. Create Access Keys

### 2.1 Generate Access Key

1. Navigate to **IAM → Users → terraform-admin**
2. Go to **Security credentials** tab
3. Scroll to **Access keys**
4. Click **Create access key**

### 2.2 Select Use Case

- Choose: **Command Line Interface (CLI)**
- Confirm the recommendation
- Click **Next**

### 2.3 Set Description (Optional)

- Description tag: `terraform`
- Click **Create access key**

### 2.4 Save Credentials

AWS will show your credentials **only once**:

- **Access key ID**: `AKIAXXXXXXXXXXXXXXXX`
- **Secret access key**: `xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`

**⚠️ CRITICAL**: Download or copy these credentials immediately. They will not be shown again.

Click **Done**

## 3. Configure AWS CLI

### 3.1 Verify Prerequisites

Ensure you're running as a normal user (not root):

```bash
whoami
```

### 3.2 Install AWS CLI (if needed)

#### Check if Installed

```bash
aws --version
```

#### Install on Ubuntu/Debian

```bash
sudo apt update
sudo apt install -y curl unzip
curl -sS https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o awscliv2.zip
unzip awscliv2.zip
sudo ./aws/install
```

#### Install on macOS

```bash
brew install awscli
```

#### Verify Installation

```bash
aws --version
```

Expected output:

```
aws-cli/2.x.x Python/3.x.x ...
```

### 3.3 Configure AWS Profile

Create a named profile for Terraform:

```bash
aws configure --profile terraform
```

Enter your credentials when prompted:

```
AWS Access Key ID [None]: AKIAXXXXXXXXXXXXXXXX
AWS Secret Access Key [None]: xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
Default region name [None]: eu-north-1
Default output format [None]: json
```

### 3.4 Secure Credentials

Lock down permissions on AWS credential files:

```bash
chmod 700 ~/.aws
chmod 600 ~/.aws/credentials ~/.aws/config
```

### 3.5 Verify Configuration

```bash
# Check profile configuration
aws configure list --profile terraform

# Verify identity
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

**✅ Success Indicators**:

- `Arn` shows `user/terraform-admin` (not `root`)
- `Account` matches your AWS account ID (12-digit number)

## 4. Validate Terraform Authentication

### 4.1 Create Test Directory

```bash
mkdir -p ~/tf-auth-test
cd ~/tf-auth-test
```

### 4.2 Create Test Configuration

Create `main.tf`:

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.14"
    }
  }
}

provider "aws" {
  region  = "eu-north-1"
  profile = "terraform"
}

data "aws_caller_identity" "current" {}

output "account_id" {
  value       = data.aws_caller_identity.current.account_id
  description = "AWS Account ID"
}

output "arn" {
  value       = data.aws_caller_identity.current.arn
  description = "IAM user ARN"
}
```

### 4.3 Initialize and Test

```bash
# Initialize Terraform
terraform init

# Apply (read-only test)
terraform apply -auto-approve
```

Expected output:

```
data.aws_caller_identity.current: Reading...
data.aws_caller_identity.current: Read complete after 0s

Apply complete! Resources: 0 added, 0 changed, 0 destroyed.

Outputs:

account_id = "<your_account_id>"
arn = "arn:aws:iam::<your_account_id>:user/terraform-admin"
```

**✅ Success**:

- No errors during `terraform init`
- Data source read successfully
- Output shows correct IAM user ARN
- `0 added, 0 changed, 0 destroyed` (read-only operation)

### 4.4 Clean Up Test

```bash
cd ~
rm -rf ~/tf-auth-test
```

## 5. Using Credentials with This Project

### Method 1: AWS Profile (Recommended)

Set the profile and region as environment variables:

```bash
export AWS_PROFILE=terraform
export AWS_REGION=eu-north-1
```

**What these do**:

- `AWS_PROFILE=terraform` - Tells Terraform and AWS CLI to use the credentials from the `[terraform]` profile in `~/.aws/credentials`
- `AWS_REGION=eu-north-1` - Sets the default AWS region for all operations (Stockholm region in this case)

**Why we need these**:

Terraform needs to know:
1. **Which credentials to use** - Without `AWS_PROFILE`, it would look for default credentials
2. **Which region to deploy to** - Without `AWS_REGION`, Terraform would require region in every command

**Make these permanent** (optional but recommended):

Add to your shell profile so you don't need to export them every time:

```bash
echo 'export AWS_PROFILE=terraform' >> ~/.bashrc
echo 'export AWS_REGION=eu-north-1' >> ~/.bashrc
source ~/.bashrc
```

**Verify they're set**:

```bash
echo $AWS_PROFILE    # Should output: terraform
echo $AWS_REGION     # Should output: eu-north-1
```

### Method 2: Environment Variables

Alternatively, export credentials directly:

```bash
export AWS_ACCESS_KEY_ID="AKIAXXXXXXXXXXXXXXXX"
export AWS_SECRET_ACCESS_KEY="xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
export AWS_REGION="eu-north-1"
```

**⚠️ Warning**: Never hardcode credentials in `.tf` files or commit them to version control.

## Troubleshooting

### Wrong Identity Returned

If `aws sts get-caller-identity` returns root instead of your IAM user:

```bash
# Check which credentials are being used
aws configure list --profile terraform

# Verify access key matches
aws iam list-access-keys --user-name terraform-admin --profile terraform

# Edit credentials file if needed
vim ~/.aws/credentials
```

### No Valid Credentials

If Terraform fails with "no valid credential sources":

```bash
# Verify profile exists
cat ~/.aws/credentials

# Verify environment variables
echo $AWS_PROFILE
echo $AWS_REGION

# Re-run aws configure if needed
aws configure --profile terraform
```

### Permission Denied Errors

If operations fail with permission errors:

```bash
# Check user's effective permissions
aws iam list-attached-user-policies --user-name terraform-admin --profile terraform

# Check group permissions
aws iam list-attached-group-policies --group-name terraform-admins --profile terraform
```

## Security Best Practices

### Access Key Rotation

Rotate access keys periodically:

1. Create a new access key
2. Update `~/.aws/credentials` with new key
3. Test with `aws sts get-caller-identity`
4. Delete old access key from AWS Console

### Least Privilege

For production environments:

- Replace `AdministratorAccess` with specific permissions
- Use separate IAM users for different environments
- Enable MFA for IAM users
- Use IAM roles instead of access keys when possible

### Credential Management

- Never commit credentials to git
- Never hardcode credentials in code
- Use AWS Secrets Manager or Parameter Store for sensitive data
- Regularly audit IAM users and keys

## Next Steps

Once AWS credentials are configured:

1. Clone this repository
2. Follow the [README.md](../README.md) for infrastructure deployment
3. Use helper scripts in `scripts/` directory

## Additional Resources

- [AWS IAM Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)
- [AWS CLI Configuration](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html)
- [Terraform AWS Provider Authentication](https://registry.terraform.io/providers/hashicorp/aws/latest/docs#authentication-and-configuration)
