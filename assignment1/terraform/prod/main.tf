# Environment-specific values only. Every resource lives in the module.
module "webstack" {
  source = "../modules/webstack"

  environment = "prod"
  release     = "v1"
  vpc_cidr    = "10.30.0.0/16"

  public_subnets = {
    a = { cidr_block = "10.30.1.0/24", az_index = 0 }
    b = { cidr_block = "10.30.2.0/24", az_index = 1 }
  }

  instance_type       = "t3.micro"
  ssm_parameter_name  = "/acs730/prod/db_password"
  alarm_cpu_threshold = 70
}
