module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0"

  name = local.name
  cidr = local.vpc_cidr

  azs             = local.azs
  private_subnets = local.private_subnets
  public_subnets  = local.public_subnets

  # One shared NAT gateway keeps the lab cheap (not highly available); instances use it for dnf and SSM
  enable_nat_gateway = true
  single_nat_gateway = true
}
