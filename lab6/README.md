# Lab 6: Ansible Configuration Management and Golden AMIs

## Runner-to-instance mechanism

The pipeline reaches the instances through **AWS Systems Manager Session Manager**, using the same temporary Academy session credentials the runner already has for Terraform. The SSM agent on each instance opens the connection outbound over port 443, so the security group has no port 22 rule and there is no SSH key to generate, store in repository secrets, rotate, or leak. The only other sanctioned option, an ephemeral per-run key pair, is what Packer uses for its own build instance in Part 8: it creates a temporary key pair and security group, then deletes both when the build ends.

## What changed=0 on a second run proves

A second run reporting `changed=0` on both hosts proves that every task checked the real state of the host and found it already matched what the role asks for, not that the playbook did nothing. That is what makes the same command safe to run on a fresh instance and on a converged one, and safe to run from a pipeline on every merge.

## Why deregistering an AMI is not enough

The AMI is only a pointer; the EBS snapshot behind it holds the data and is what bills, so deregistering leaves the snapshot behind, and once the AMI is gone `describe-images` can no longer tell you which snapshot belonged to it. Read the snapshot ID first, then deregister, then delete the snapshot.

## Boot-to-ready: converge-on-boot vs golden AMI

Both were measured with `scripts/boot-to-ready.sh`, from the moment AWS was asked for an instance to the first HTTP 200.

| Path | Seconds | What the time includes |
|---|---|---|
| Converge-on-boot (stock AL2023 + Ansible) | 148 | Terraform destroying the old instance (~30 s), instance launch and boot, SSM agent registration, the Ansible run (dnf, user, directory, two templates, service start) |
| Golden AMI (Packer) | 19 | Instance launch and boot, service start; everything else was done at build time |

Both proofs for the golden instance passed: the page showed `Build: golden-ami` (the `--extra-vars` override from Packer), and `/baked.html` returned 200, a file the role never creates.

### Where the time went in the slow path

Not in the Ansible logic. Most of it was waiting: about 30 s for Terraform to destroy the instance being replaced, then for the new instance to boot and its SSM agent to register before Ansible could connect at all, then for dnf to check packages over the network. That cost is paid once per instance, on every launch.

### The cost a golden AMI moves rather than removes

The work still happens, once at build time instead of N times at launch time: the Packer build took 3 min 11 s. One instance does not repay that (3 min 11 s of build to save about 2 minutes), but from the second or third instance onwards the image wins, and it wins more with every launch.

### What breaks with each

- **Golden AMI:** an image is a frozen moment, so security updates released after the bake are not in it and it needs a rebuild schedule; and you cannot see what is inside it without the build log, whereas a playbook is its own documentation.
- **Converge-on-boot:** every launch depends on SSM, the package mirrors and the network being available at that moment. A mirror outage means instances that boot but never become ready, which is exactly the wrong failure during an autoscaling event at 3 a.m.

### Recommendation

Golden AMI, because production servers are launched in groups and by autoscaling, where a 19-second boot-to-ready with no network dependency matters more than build time; I would switch to converge-on-boot only for a single long-lived server whose configuration changes more often than it is relaunched.

## SSM bucket and region

The `aws_ssm` connection stages file transfers through an S3 bucket (`acs730-lab6-ssm-<account-id>`), and `ansible_aws_ssm_bucket_name` and `ansible_aws_ssm_region` in `group_vars/role_web.yml` must both point at the bucket's real region, `us-east-1`. If they disagree, the first task fails with `PermanentRedirect`.
