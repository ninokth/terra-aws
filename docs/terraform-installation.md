# Terraform Installation Guide

This guide covers installing Terraform with GPG signature verification for security best practices.

## Quick Installation (Package Manager)

### Ubuntu/Debian

```bash
# Add HashiCorp GPG key
wget -O- https://apt.releases.hashicorp.com/gpg | \
  sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

# Add HashiCorp repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
  sudo tee /etc/apt/sources.list.d/hashicorp.list

# Install Terraform
sudo apt update && sudo apt install terraform
```

### macOS

```bash
# Using Homebrew
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
```

### Verify Installation

```bash
terraform version
```

Expected output:

```
Terraform v1.14.3
on linux_amd64
```

## Manual Binary Installation (with GPG Verification)

For maximum security, manually download and verify the Terraform binary.

### Step 1: Set Version Variables

```bash
export PRODUCT=terraform
export VERSION=1.14.3
export OS_ARCH=linux_amd64
```

### Step 2: Create Verification Directory

```bash
mkdir -p verify-terraform-binary
cd verify-terraform-binary
```

### Step 3: Set Up GPG Environment

```bash
# Create temporary GPG configuration
export GNUPGHOME=./.gnupg

# Generate temporary personal key (for signing HashiCorp's key)
gpg --quick-generate-key --batch --passphrase "" your-email@example.com
```

### Step 4: Download HashiCorp Public Key

```bash
# Download HashiCorp's public keys
curl --remote-name https://www.hashicorp.com/.well-known/pgp-key.txt

# Import the keys into your GPG keychain
gpg --import pgp-key.txt

# Sign the key with your temporary key
gpg --sign-key <KEY_ID_FROM_OUTPUT>

# Verify the public key ID and fingerprint
gpg --fingerprint --list-signatures "HashiCorp Security"
```

### Step 5: Download Terraform Binary and Checksums

```bash
# Download the binary
curl --remote-name https://releases.hashicorp.com/${PRODUCT}/${VERSION}/${PRODUCT}_${VERSION}_${OS_ARCH}.zip

# Download SHA256 checksums
curl --remote-name https://releases.hashicorp.com/${PRODUCT}/${VERSION}/${PRODUCT}_${VERSION}_SHA256SUMS

# Download checksum signature file
curl --remote-name https://releases.hashicorp.com/${PRODUCT}/${VERSION}/${PRODUCT}_${VERSION}_SHA256SUMS.sig
```

### Step 6: Verify Checksum and Signature

```bash
# Verify checksum signature
gpg --verify ${PRODUCT}_${VERSION}_SHA256SUMS.sig ${PRODUCT}_${VERSION}_SHA256SUMS

# Verify binary checksum
sha256sum --ignore-missing -c ${PRODUCT}_${VERSION}_SHA256SUMS
```

Expected output:

```
terraform_1.14.3_linux_amd64.zip: OK
```

### Step 7: Install Terraform

```bash
# Unzip the binary
unzip terraform_${VERSION}_${OS_ARCH}.zip

# Move to system path
sudo mv terraform /usr/local/bin/

# Make executable
sudo chmod 755 /usr/local/bin/terraform
```

### Step 8: Verify Installation

```bash
terraform version
```

## Version Requirements

This project requires:

- **Terraform >= 1.5**
- **AWS Provider ~> 6.14**

Check your version compatibility:

```bash
# Check Terraform version
terraform version

# Check provider versions after init
terraform -chdir=providers init
terraform -chdir=providers version
```

## Troubleshooting

### Command not found

If `terraform` command is not found after installation:

```bash
# Check if terraform is in PATH
which terraform

# If not in PATH, add to your shell profile
echo 'export PATH=$PATH:/usr/local/bin' >> ~/.bashrc
source ~/.bashrc
```

### GPG Verification Failed

If GPG verification fails:

```bash
# Ensure GPG is installed
sudo apt install gnupg

# Re-import HashiCorp key
curl https://www.hashicorp.com/.well-known/pgp-key.txt | gpg --import
```

### Permission Denied

If you get permission errors:

```bash
# Ensure terraform binary is executable
sudo chmod +x /usr/local/bin/terraform

# Verify ownership
ls -la /usr/local/bin/terraform
```

## Upgrading Terraform

### Package Manager Upgrade

```bash
# Ubuntu/Debian
sudo apt update && sudo apt upgrade terraform

# macOS
brew upgrade terraform
```

### Manual Upgrade

Follow the same manual installation steps with the new version number.

## Uninstalling Terraform

### Package Manager Uninstall

```bash
# Ubuntu/Debian
sudo apt remove terraform

# macOS
brew uninstall terraform
```

### Manual Uninstall

```bash
sudo rm /usr/local/bin/terraform
```

## Additional Resources

- [Official Terraform Downloads](https://developer.hashicorp.com/terraform/install)
- [Terraform Releases](https://releases.hashicorp.com/terraform/)
- [HashiCorp GPG Key](https://www.hashicorp.com/.well-known/pgp-key.txt)
