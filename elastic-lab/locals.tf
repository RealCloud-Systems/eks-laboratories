locals {
  # General
  name    = "elastic-lab"
  region  = "us-east-1"
  profile = "services-admin"

  tags = {
    Project   = local.name
    ManagedBy = "terraform"
  }

  # Network
  vpc_cidr        = "10.1.0.0/16"
  azs             = slice(data.aws_availability_zones.available.names, 0, 2)
  private_subnets = [for i, _ in local.azs : cidrsubnet(local.vpc_cidr, 4, i)]       # 10.1.0.0/20, 10.1.16.0/20
  public_subnets  = [for i, _ in local.azs : cidrsubnet(local.vpc_cidr, 8, 192 + i)] # 10.1.192.0/24, 10.1.193.0/24

  # Spot applies these tags to every instance it launches; FIS and SSM find the instances through them
  instance_tags = merge(local.tags, {
    Name                = "${local.name}-app"
    "elastic-lab/group" = local.name
  })

  # nginx answers with the app version and where the instance runs, so a curl shows which instance replied
  user_data = <<-EOT
    #!/bin/bash
    set -euo pipefail
    dnf install -y nginx

    TOKEN=$(curl -sX PUT http://169.254.169.254/latest/api/token -H "X-aws-ec2-metadata-token-ttl-seconds: 300")
    md() { curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/$1; }

    echo "version=${var.app.version} instance=$(md instance-id) type=$(md instance-type) az=$(md placement/availability-zone) lifecycle=$(md instance-life-cycle)" \
      > /usr/share/nginx/html/index.html

    systemctl enable --now nginx
  EOT
}
