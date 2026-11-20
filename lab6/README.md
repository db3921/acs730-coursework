# Lab 6: Ansible Configuration Management and Golden AMIs

## Runner-to-instance mechanism

The pipeline reaches the instances through **AWS Systems Manager Session Manager**, using the same temporary Academy session credentials the runner already has for Terraform. The SSM agent on each instance opens the connection outbound over port 443, so the security group has no port 22 rule and there is no SSH key to generate, store in repository secrets, rotate, or leak. The only other sanctioned option, an ephemeral per-run key pair, is what Packer uses for its own build instance in Part 8: it creates a temporary key pair and security group, then deletes both when the build ends.
