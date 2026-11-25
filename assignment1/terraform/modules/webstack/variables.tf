# Inputs are the values that differ between dev, staging and prod.
# Anything identical in all three is a local, not an input.

variable "environment" {
  description = "Which copy of the stack this is."
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging or prod."
  }
}

variable "project" {
  description = "Name prefix for every resource."
  type        = string
  default     = "acs730-a1"
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,23}$", var.project))
    error_message = "project: 3-24 lowercase letters, digits, hyphens, starting with a letter."
  }
}

variable "release" {
  description = "Release label tagged on the instance. Bumping it is the change promoted through staging to prod."
  type        = string
  default     = "v1"
}

variable "vpc_cidr" {
  description = "CIDR block for this environment's VPC. Different per environment."
  type        = string
  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "vpc_cidr must be a valid IPv4 CIDR, for example 10.10.0.0/16."
  }
}

variable "public_subnets" {
  description = "Public subnets to create, keyed by a short stable name."
  type = map(object({
    cidr_block = string
    az_index   = number
  }))
}

variable "ingress_rules" {
  description = "Ingress rules for the web security group. No port 22: access is Session Manager."
  type = list(object({
    description = string
    port        = number
    cidr_blocks = list(string)
  }))
  default = [
    { description = "HTTP from anywhere", port = 80, cidr_blocks = ["0.0.0.0/0"] },
  ]
}

variable "instance_type" {
  description = "Instance type for the web server."
  type        = string
  default     = "t3.micro"
  validation {
    condition     = contains(["t3.micro", "t3.small"], var.instance_type)
    error_message = "Stay small: t3.micro or t3.small. The term budget is $50 in total."
  }
}

variable "ami_id" {
  description = "Optional AMI id (for example a Packer golden AMI). null means the latest Amazon Linux 2023."
  type        = string
  default     = null
}

variable "ssm_parameter_name" {
  description = "SSM Parameter Store name of the application secret. Created by hand, out of band; Terraform only reads it."
  type        = string
  validation {
    condition     = startswith(var.ssm_parameter_name, "/")
    error_message = "ssm_parameter_name must be a full path starting with /."
  }
}

variable "alarm_cpu_threshold" {
  description = "Average CPU percent above which the CloudWatch alarm fires."
  type        = number
  default     = 80
  validation {
    condition     = var.alarm_cpu_threshold > 0 && var.alarm_cpu_threshold <= 100
    error_message = "alarm_cpu_threshold must be between 1 and 100."
  }
}
