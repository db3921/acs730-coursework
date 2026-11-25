data "aws_ami" "al2023" {
  count = var.ami_id == null ? 1 : 0

  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-kernel-6.1-x86_64"]
  }
}

# Task 6: Terraform READS the application secret; it never creates it.
# The parameter is created once, by hand, with aws ssm put-parameter.
# with_decryption = false: Terraform only needs to know the parameter
# exists and which version it is, so the plaintext never enters state.
# The instance reads the value itself at boot, through its instance profile.
data "aws_ssm_parameter" "app_secret" {
  name            = var.ssm_parameter_name
  with_decryption = false
}

locals {
  ami_id           = var.ami_id != null ? var.ami_id : data.aws_ami.al2023[0].id
  first_subnet_key = keys(local.public_subnets)[0]
}

resource "aws_instance" "web" {
  ami                    = local.ami_id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public[local.first_subnet_key].id
  vpc_security_group_ids = [aws_security_group.web.id]

  # The Academy-provided profile: lets the SSM agent register (Session
  # Manager instead of SSH) and lets the instance read its own secret.
  iam_instance_profile = "LabInstanceProfile"

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    encrypted = true
  }

  user_data = <<-EOT
    #!/bin/bash
    set -euo pipefail
    dnf -y install nginx
    mkdir -p /etc/acs730
    if ( umask 077 && aws ssm get-parameter --region ${data.aws_region.current.name} --name ${var.ssm_parameter_name} --with-decryption --query Parameter.Value --output text > /etc/acs730/app_secret ); then
      SECRET_STATUS="loaded from Parameter Store (${var.ssm_parameter_name})"
    else
      SECRET_STATUS="NOT loaded - check the instance profile"
    fi
    echo "<h1>ACS730 Assignment 1 - ${local.name}</h1><p>Environment: ${var.environment}</p><p>App secret: $SECRET_STATUS</p>" > /usr/share/nginx/html/index.html
    systemctl enable --now nginx
  EOT

  # Without this, Terraform may build the instance before the default
  # route exists; dnf then hangs and nginx never installs (Lab 5).
  depends_on = [aws_route_table_association.public]

  tags = merge(local.common_tags, {
    Name               = "${local.name}-web"
    Release            = var.release
    AppSecretParameter = var.ssm_parameter_name
    AppSecretVersion   = tostring(data.aws_ssm_parameter.app_secret.version)
  })
}
