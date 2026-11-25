# One bucket, one key per environment. The key is the whole safety
# mechanism: two environments sharing a key destroy each other.
terraform {
  backend "s3" {
    bucket       = "acs730-tfstate-423739922781"
    key          = "assignment1/dev/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
