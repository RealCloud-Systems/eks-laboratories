data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  # General
  name   = "eks-workshop"
  region = "us-east-1"

  profile        = "services-admin"
  backend_bucket = "realcloud-services-terraform-state"

  tags = {
    Project   = local.name
    ManagedBy = "terraform"
  }

  # Network
  vpc_cidr        = "10.0.0.0/16"
  azs             = slice(data.aws_availability_zones.available.names, 0, 2)
  private_subnets = [for i, _ in local.azs : cidrsubnet(local.vpc_cidr, 4, i)]       # 10.0.0.0/20, 10.0.16.0/20
  public_subnets  = [for i, _ in local.azs : cidrsubnet(local.vpc_cidr, 8, 192 + i)] # 10.0.192.0/24, 10.0.193.0/24

  # Compute
  eks = {
    cluster_version = "1.37"
    node_group = {
      instance_types = ["t3.medium"]
      # Only hosts the Ocean controller and cluster add-ons; Ocean runs the workloads
      min_size     = 1
      max_size     = 2
      desired_size = 1
    }
  }

}
