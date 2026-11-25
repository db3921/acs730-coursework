# Assignment 1 - Multi-Environment Infrastructure Deployment with Terraform

Darek Bielski (dbielski)

## Introduction

This assignment takes the single-environment Terraform from Lab 5 and makes it something a team could run in production. All the infrastructure now lives in one reusable module, `webstack`. Three small environment directories call that module: `dev`, `staging` and `prod`. Each environment gets its own VPC, web server, secret and alarm, and each keeps its own state.

A GitHub Actions workflow promotes changes. A merge to `main` applies staging automatically. Prod then stops and waits until a named reviewer reads what staging did and approves it.

That gate is the point of the design. Staging is where a change proves itself; prod should only receive a change a person has looked at. The approval step also records who approved what, and when.

## Reusable module (Task 1)

The module is `assignment1/terraform/modules/webstack/`. It holds every resource:
- a VPC, two public subnets, an internet gateway and a route table
- a security group with port 80 only and **no port 22**
- one EC2 instance with `LabInstanceProfile`, so access is through Session Manager
- the SSM parameter data source
- the CloudWatch alarm

It is split by concern into `network.tf`, `compute.tf` and `monitoring.tf`, plus `variables.tf`, `outputs.tf` and `versions.tf`.

| Input | Why it is an input |
|---|---|
| `environment` | names and tags differ per environment |
| `vpc_cidr`, `public_subnets` | each environment gets its own non-overlapping range |
| `instance_type` | prod could be sized up independently |
| `release` | the value promoted through staging to prod |
| `ssm_parameter_name` | each environment reads its own secret |
| `alarm_cpu_threshold` | prod alerts earlier (70%) than dev and staging (80%) |
| `ami_id` | optional; lets a golden AMI replace the default AL2023 image |

Anything identical in all three environments is a local, not an input. Examples are the `acs730-a1-<environment>` name prefix, the common tags, and the dependency that makes the instance wait for the route table association. Inputs carry validation where a bad value would be expensive. `environment` must be dev, staging or prod; `instance_type` must be t3.micro or t3.small; `vpc_cidr` must be a valid CIDR; and the alarm threshold must be 1-100.

The module's outputs are:
- `vpc_id` and `subnet_ids`
- `instance_id`
- `web_public_ip` and `web_url`
- `alarm_name`
- `app_secret_parameter` and `app_secret_version`, which are the parameter's name and version, never its value

Each environment's `outputs.tf` passes on the ones an operator needs. The evidence was captured from them: `curl "$(terraform output -raw web_url)"` checked each deployment, and the alarm name led to `cloudwatch-alarm.json`. The network outputs are there for later work, for example the final project, so another configuration can place resources in the same VPC without guessing at ids.

## Environment directories (Task 2)

`dev/`, `staging/` and `prod/` each call `../modules/webstack` and differ only in the values they pass. Each has its own state key in one bucket:

- `assignment1/dev/terraform.tfstate`
- `assignment1/staging/terraform.tfstate`
- `assignment1/prod/terraform.tfstate`

Evidence: `evidence/backend-state-keys.txt`.

Staging and prod were made by copying `dev/` and changing four values, plus a fifth in prod, in one step before the first `terraform init`:
- the state key
- the environment name
- the SSM parameter path
- the CIDR range
- in prod only, the alarm threshold

`diff -r` between the directories shows exactly those lines and nothing else.

Separate directories were chosen over Terraform workspaces because they make the environment visible:
- **Where you are:** you can see which environment you are in from your shell prompt.
- **What a change touches:** a pull request that touches prod shows `prod/` in its changed-file list.
- **Which state you are using:** each backend key is written in a file you can read.

With workspaces, all three environments share identical files. The only difference is a hidden `terraform workspace select`, and forgetting it applies a dev change to prod with no warning. With a pipeline pointed at a real account, being explicit is worth the small amount of duplication.

## GitHub Environments (Task 3)

- `staging`: no protection rules; applies automatically on merge to main.
- `prod`: one required reviewer (db3921) and a deployment branch policy allowing only `main`.

Evidence: `evidence/environments.json`, `evidence/prod-approval-pending.png`, `evidence/prod-approval-approved.png`.

## Scoped credentials and OIDC trust policy (Task 4)

The three AWS secrets now exist only on the `staging` and `prod` environments; the repository-level copies were deleted (`evidence/secrets-scope.txt`). The per-session refresh is:

    ./scripts/refresh-gha-creds.sh db3921/acs730-coursework staging prod

Known consequence: older workflows (`lab3-deploy.yml`, `lab6-configure.yml`) read repository-level secrets and would fail if re-run; they are path-scoped to their own folders and are not triggered by this work.

In a real AWS account the prod job would assume a role through GitHub OIDC and no credential would be stored at all. The trust policy for that role:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "GitHubActionsProdDeployOnly",
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::423739922781:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
          "token.actions.githubusercontent.com:sub": "repo:db3921/acs730-coursework:environment:prod"
        }
      }
    }
  ]
}
```

What each part prevents:

- **`Principal.Federated`:** only tokens signed by GitHub's OIDC provider, as registered in this AWS account, are accepted. A token from any other identity provider, or one anyone could forge, cannot be presented to this role.
- **`Action: sts:AssumeRoleWithWebIdentity`:** the job swaps a short-lived signed token for temporary credentials. They last about an hour by default. There is no stored access key that could leak, be copied into a fork, or need rotating.
- **`aud = sts.amazonaws.com`:** the token must have been minted *for AWS STS*. Without this check, a token GitHub issued for some other service could be replayed here to assume the role.
- **`sub = repo:db3921/acs730-coursework:environment:prod`:** this is the condition that matters most. GitHub sets `sub` from the job itself. It reads `environment:prod` only when the job declares `environment: prod`, and declaring that environment brings its protection rules with it: a required reviewer, and deployment from `main` only. So the only way to obtain prod credentials is a reviewed job running from `main`.
  - Compare the loose form, `repo:db3921/acs730-coursework:*`. Anyone with push access to any branch could add a workflow file on a throwaway branch and assume the prod role from it. No review, no `main`, no environment would be involved.
  - The environment-pinned `sub` closes that path, because a job on a side branch cannot claim the prod environment: the branch policy refuses it.
- **`StringEquals` rather than `StringLike`:** the values must match exactly. No wildcard can be slipped in, so a typo or a broadened pattern cannot silently widen who may assume the role.

**Why it was not deployed:** the Learner Lab denies every IAM write, so the OIDC provider and the role cannot be created. Session-scoped credentials that expire with the lab session are the Academy substitute, and they are scoped to the two environments that deploy.

## Real deployment (Task 5)

The deployment was promoted through pull request #39 (`assignment1` → `main`).

1. **The change:** the last commit on the branch changed `release` from `v1` to `v2` in `staging/main.tf` and `prod/main.tf`. That is an in-place tag update on the web server, so it is a real change, but it does not rebuild anything.
2. **The PR check:** the pull request ran only "fmt and validate" and needed no credentials. The staging and prod jobs were skipped because they run only on a push to `main`.
3. **The merge:** merging created commit `c88c499` on `main` and started `assignment1-deploy` run #4.
4. **Staging:** it applied automatically in 24 seconds. Plan: `0 to add, 1 to change, 0 to destroy`, then `Apply complete! Resources: 0 added, 1 changed, 0 destroyed.`
5. **The gate:** prod then stopped with "prod waiting for review" (`prod-approval-pending.png`). Before approving, I read the staging log and confirmed the plan was the one expected change and contained no destroy.
6. **Prod:** after approval (`prod-approval-approved.png`), prod ran the same plan and apply with the same result, `1 changed`.

Evidence: `evidence/staging-apply.txt`, `evidence/prod-apply.txt`.

Staging and prod had first been applied from the workstation during setup. The merge-triggered run is the one that *promoted a change* through both, which is what the gate exists for.

## Secrets management (Task 6)

Pre-step, run once per environment by hand from the workstation (the value is random and never printed):

    aws ssm put-parameter --region us-east-1 --name /acs730/prod/db_password --type SecureString --value "$(openssl rand -base64 24)"

Terraform reads it with `data "aws_ssm_parameter" "app_secret"`. Nothing in the Terraform creates it: `grep -rn aws_ssm_parameter` finds one data source and no resource.

**Why there is no resource.** A resource and a data source for the same name would ask Terraform to create the parameter and read it in the same graph.
- On a fresh environment, which is exactly what CI plans against, the read happens before the parameter exists, so the plan fails.
- It would also put the secret's value into a `.tf` file or variable, the place the secret must never appear.
- Creating the parameter out of band, documented here as the pre-step, keeps the value out of the code entirely.

**Why `with_decryption = false`.** Terraform needs to know only that the parameter exists, plus its name and version.
- With decryption off, the state holds the encrypted form instead of the plaintext.
- The module tags the instance with the parameter's name and version (`AppSecretParameter`, `AppSecretVersion`) but never its value.

**How the application gets the value.** The instance fetches the parameter itself at boot, through its instance profile, with `aws ssm get-parameter --with-decryption`.
- It writes the value to `/etc/acs730/app_secret` under `umask 077`, so only root can read it.
- The web page reports only whether the load succeeded: "App secret: loaded from Parameter Store (/acs730/prod/db_password)".
- Rotating the secret means a new parameter version. The next boot reads it, and no code changes.

Evidence: `evidence/ssm-parameter.txt`.

## CloudWatch alarm (Task 7)

`acs730-a1-<env>-cpu-high` fires when average `CPUUtilization` is above the threshold for two 5-minute periods. The threshold is 80% in staging and 70% in prod.

CPU was chosen because EC2 reports it every five minutes even on an idle instance. The alarm therefore collects real datapoints and settles at **OK**, as both alarms showed when captured. A request-based metric on a server nobody calls would have no datapoints and would stay at `INSUFFICIENT_DATA`. Prod's lower threshold gives earlier warning where it matters most.

With real traffic I would add:
- `StatusCheckFailed`, to catch a dead instance
- a load balancer's 5xx count or latency, to catch a server that is up but failing requests
- an SNS action, so the alarm notifies someone

These alarms have no action, because "No actions" was enough for this assignment.

Evidence: `evidence/cloudwatch-alarm.json`, `evidence/cloudwatch-alarm.png`.

## Recommendation: GitHub Actions or an AWS-native pipeline? (Task 8)

**Recommendation:** for a team fully committed to AWS with no multi-cloud plans, I would keep **GitHub Actions**, with OIDC federation to one IAM role per environment. I would add a small AWS-native piece only where a deploy has to reach inside a private VPC. Four factors decide it.

1. **Where the deploy identity lives.**
   - This is the strongest argument for AWS-native tools: CodePipeline and CodeBuild run *as* an IAM role, with no federation at all.
   - OIDC closes most of that gap. GitHub's runner holds no stored credential, and the trust policy above limits the prod role to reviewed jobs from `main`.
   - The remaining difference is one trust relationship to look after. That is a configuration task, not a security gap.

2. **Where the review happens.**
   - The code, pull requests, required checks and approval gate already live in GitHub. In this assignment, one pull request carried the change, its validation, the staging apply and the prod approval, all linked on one page.
   - CodePipeline has manual approval actions, but the reviewer then approves in the AWS console, away from the diff being approved.
   - Moving the gate out of GitHub splits one review into two tools.

3. **Runner cost and patching.**
   - GitHub-hosted runners cost nothing to run and need no patching. This repository's public minutes are free, and a private repo would pay per minute.
   - CodeBuild also needs no patching, but it bills per build-minute, and its build images and pipeline definitions are a second system the team has to learn and maintain.
   - For a small team, one CI system is cheaper than two.

4. **What the team already knows, and VPC-internal access.**
   - The team already writes GitHub Actions YAML for every other check (lint, test, image build, security scan). Using the same tool for deploys keeps one mental model.
   - The real weakness of GitHub-hosted runners is that they sit on the public internet. A deploy that has to reach a private database or an internal endpoint cannot run there.
   - That is the case where I would add either a self-hosted runner inside the VPC (as in Week 10) or a single CodeBuild project the GitHub workflow triggers. That is a targeted fix for one constraint, not a reason to move the whole pipeline.

If the organisation's controls required every deploy credential to be issued only inside AWS, with no external identity provider trusted at all, the answer would change to CodePipeline. Without that requirement, GitHub Actions with OIDC gives the same security with one fewer system to run.

## Conclusion

**What I learned:**
- Most of the risk in multi-environment Terraform is not in the resources; it is in the plumbing around them.
- A copied backend key would have let one environment's apply destroy another's, which is why the key changed in the same edit as the copy, before any `init`.
- A credential refresh can keep "succeeding" while writing secrets no job can read. The refresh command changed form once the secrets moved to environments.
- A plan has to be *read*. Every apply in this assignment, local or in the pipeline, was checked for `-/+` and destroy before it went ahead.

**What I would do differently:**
1. **Use the pipeline from the start.** I would let the pipeline perform the first applies of staging and prod, instead of applying them from the workstation and then promoting a change. Then every change to staging and prod would have a run log.
2. **Plan on pull requests.** The PR check would run `terraform plan` against staging with read-only credentials and post the plan as a PR comment. The reviewer would then see the exact change before merging, not only after staging has applied it.
3. **Separate roles per environment.** In a real account, staging and prod would use separate IAM roles. A bug in staging automation could then never act on prod.
4. **Better monitoring.** I would add the `StatusCheckFailed` alarm and an SNS notification, so the alarm reaches a person.
