data "terraform_remote_state" "eks" {
  backend = "s3"

  config = {
    bucket  = "realcloud-services-terraform-state"
    key     = "eks-workshop/terraform.tfstate"
    region  = "us-east-1"
    profile = "services-admin"
  }
}

# EKS optimized Amazon Linux 2023 images, one per architecture
data "aws_ssm_parameter" "ami" {
  for_each = toset(["x86_64", "arm64"])

  name = "/aws/service/eks/optimized-ami/${local.cluster.version}/amazon-linux-2023/${each.key}/standard/recommended/image_id"
}

data "aws_caller_identity" "current" {}
