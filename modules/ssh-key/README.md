# SSH Key Module

Manages AWS key pair for EC2 instance access.

## Resources Created

- AWS Key Pair

## Inputs

| Name | Description | Type | Required |
|------|-------------|------|----------|
| `name_prefix` | Prefix for resource names | `string` | Yes |
| `public_key` | SSH public key content | `string` | Yes |
| `tags` | Tags to apply | `map(string)` | No |

## Outputs

| Name | Description |
|------|-------------|
| `key_pair_name` | Name of the SSH key pair |
| `key_pair_id` | ID of the SSH key pair |
| `key_pair_fingerprint` | Fingerprint of the key |

## Usage

```hcl
module "ssh_key" {
  source = "../modules/ssh-key"

  name_prefix = "VMs_2x_public_private"
  public_key  = file("~/.ssh/id_ed25519.pub")
  tags        = { Environment = "dev" }
}
```

## Notes

- Uses Ed25519 keys (recommended)
- Public key should be generated locally
- Key generation: `./scripts/setup_ssh_key.sh`
- Key cleanup: `./scripts/cleanup_ssh_key.sh`
