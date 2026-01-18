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

  name_prefix = "my-project"
  public_key  = file("~/.ssh/id_ed25519.pub")
  tags        = { Environment = "dev" }
}
```

## Notes

- Uses Ed25519 keys (recommended)
- Public key should be generated locally
- Key generation: `./scripts/setup_ssh_key.sh`
- Key cleanup: `./scripts/cleanup_ssh_key.sh`

## Status

**Pending extraction** - See [TRRAWS-001-P1.3-ssh-key-module](../Notes/tickets/TRRAWS-001-P0.0-refactoring-plan/TRRAWS-001-P1/TRRAWS-001-P1.3-ssh-key-module/)
