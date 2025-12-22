# Contributing to AWS Bastion Host Infrastructure

Thank you for your interest in contributing to this project.

## License Agreement

By contributing to this project, you agree that:

1. Your contributions will be licensed under the [MIT License](LICENSE)
2. You retain copyright to your contributions
3. You grant an irrevocable license for the project to use your contributions under MIT terms
4. You do not claim any additional license rights beyond those granted by MIT

## How to Contribute

### Reporting Issues

1. Check existing issues to avoid duplicates
2. Use a clear, descriptive title
3. Include steps to reproduce the problem
4. Include Terraform and AWS CLI versions
5. Include relevant error messages or logs

### Submitting Changes

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/your-feature`)
3. Make your changes
4. Test your changes (see Testing below)
5. Commit with clear messages
6. Push to your fork
7. Open a Pull Request

### Commit Messages

Use clear, descriptive commit messages:

```
Add NAT gateway health check script

- Adds script to verify NAT routing is working
- Includes timeout and retry logic
- Updates documentation with usage examples
```

### Testing Changes

Before submitting:

1. Run `terraform fmt` to format HCL files
2. Run `terraform validate` in the providers directory
3. If possible, test a full deployment cycle:
   - `./scripts/first_time_setup.sh`
   - `./scripts/deploy.sh`
   - `./scripts/test_infrastructure.sh`
   - `./scripts/destroy.sh`

### Code Style

**Terraform files:**

- Use `terraform fmt` for consistent formatting
- Use descriptive resource names
- Add comments for non-obvious logic
- Group related resources in the same file

**Shell scripts:**

- Use `#!/usr/bin/env bash`
- Include `set -euo pipefail` for safety
- Source common functions from `scripts/lib/common.sh`
- Use the logging functions (`log_info`, `log_success`, `log_error`)

**Documentation:**

- Keep guides task-oriented
- Include complete examples with expected output
- Add troubleshooting sections for common issues

## What to Contribute

Contributions welcome in these areas:

- Bug fixes
- Documentation improvements
- Additional helper scripts
- Security enhancements
- Support for additional AWS regions
- CI/CD pipeline improvements

## Questions

For questions about contributing, open an issue with the "question" label.
