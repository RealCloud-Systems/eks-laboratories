terraform {
  required_version = "~> 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    spotinst = {
      source  = "spotinst/spotinst"
      version = "~> 1.241"
    }
  }

  backend "s3" {
    bucket  = "realcloud-services-terraform-state"
    key     = "elastic-lab/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
    profile = "services-admin"
  }
}
