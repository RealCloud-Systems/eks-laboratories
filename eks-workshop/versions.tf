terraform {
  required_version = "~> 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {
    bucket  = "realcloud-services-terraform-state"
    key     = "eks-workshop/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
    profile = "services-admin"
  }
}

provider "aws" {
  region  = local.region
  profile = local.profile

  default_tags {
    tags = local.tags
  }
}

