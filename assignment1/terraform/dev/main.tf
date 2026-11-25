# Environment-specific values only. Every resource lives in the module.
module "webstack" {
  source = "../modules/webstack"

  environment = "dev"
  release     = "v1"
  vpc_cidr    = "10.10.0.0/16"

  public_subnets = {
    a = { cidr_block = "10.10.1.0/24", az_index = 0 }
    b = { cidr_block = "10.10.2.0/24", az_index = 1 }
  }

  instance_type       = "t3.micro"
  ssm_parameter_name  = "/acs730/dev/db_password"
  alarm_cpu_threshold = 80
}
