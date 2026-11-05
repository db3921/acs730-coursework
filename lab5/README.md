# Lab 5: Terraform Introduction and Reliable CI

## Why for_each here and count there

- Subnets use for_each because they are distinct things with stable names. Add key "c" and the plan is "1 to add, 0 to change, 0 to destroy"; remove "a" and it is "1 to destroy", "b" untouched.
- The same subnets with count would be a trap. Addresses would be [0], [1], [2]; delete the middle entry and everything after shifts down a slot, so Terraform compares public[1] in state against a different subnet in config and plans to destroy and recreate two subnets to remove one.
- The bucket uses count because the input is a yes/no about one resource: exactly two plans, "0 to add" and "1 to add", and no key to be stable about. In short — count when the question is how many, for_each when the question is which ones.

If they were mixed up: using count for the subnets means removing one subnet can destroy and recreate others that did not change, which would break anything running in them. Using for_each for the bucket adds a map of keys for something that is only ever on or off, which makes the code harder to read for no benefit.

## What I built

A Terraform configuration for a small web stack: one VPC (10.42.0.0/16), two public subnets in different availability zones, an internet gateway, a public route table, a security group allowing HTTP on port 80, one t3.micro instance running nginx, and an optional S3 bucket for artifacts. A provider switch (`use_localstack`) points the same code at LocalStack or real AWS. A GitHub Actions workflow (`lab5-ci`) runs `fmt -check` and `validate` first, then plans, applies, and destroys against a LocalStack service container. Both jobs are required checks on `main`, and a deliberate break proved they block the merge.

## Why not plan and apply against real AWS on every pull request

- It costs money per run, not per month. Every pull request builds and destroys real infrastructure; 27 students pushing a few times each is thousands of cycles against one fixed $50 pot. LocalStack costs nothing and leaves nothing.
- It needs a long-lived AWS credential in the repository. Applying from Actions means an access key in GitHub secrets, which can leak and must be rotated — and in an Academy account you cannot scope it, because IAM writes are denied, so the only key that works is a broad one.
- Academy sessions expire. Lab credentials last hours, so a pull request opened on Saturday night fails on Sunday morning for a reason unrelated to the code, and people learn to ignore red checks. A check people ignore is worse than no check.
- It is slow and flaky. Minutes each way, API rate limits, eventual-consistency errors unrelated to your change, and concurrent pull requests colliding on names and state in one account.
- Be honest about the limit. A green LocalStack run proves the configuration is coherent and the graph builds, not that IAM is right (LocalStack does not enforce it) or that user_data works (LocalStack never boots the instance). The real check belongs on merge or on a schedule, once, not per pull request.
