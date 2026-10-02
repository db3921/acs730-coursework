
terraform {
  required_version = "~> 1.10"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
  backend "s3" {
    bucket       = "acs730-tfstate-423739922781"
    key          = "lab3/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
  }
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_s3_bucket" "lab3" {
  bucket = "acs730-lab3-423739922781"

  tags = {
    Name = "acs730-lab3"
  }
}
