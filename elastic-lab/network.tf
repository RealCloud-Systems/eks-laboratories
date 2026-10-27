# Public entry point: the Elastigroup registers its instances in the target group by itself
module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 10.0"

  name    = local.name
  vpc_id  = module.vpc.vpc_id
  subnets = module.vpc.public_subnets

  enable_deletion_protection = false

  security_group_ingress_rules = {
    http = {
      from_port   = 80
      to_port     = 80
      ip_protocol = "tcp"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }
  security_group_egress_rules = {
    vpc = {
      ip_protocol = "-1"
      cidr_ipv4   = local.vpc_cidr
    }
  }

  listeners = {
    http = {
      port     = 80
      protocol = "HTTP"
      forward = {
        target_group_key = "app"
      }
    }
  }

  target_groups = {
    app = {
      name_prefix          = "app-"
      protocol             = "HTTP"
      port                 = 80
      target_type          = "instance"
      deregistration_delay = 30
      create_attachment    = false # targets come from the Elastigroup

      health_check = {
        path                = "/"
        interval            = 10
        timeout             = 5
        healthy_threshold   = 2
        unhealthy_threshold = 2
        matcher             = "200"
      }
    }
  }
}

# Instances only take traffic from the ALB; SSM Session Manager replaces SSH
module "app_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name        = "${local.name}-app"
  description = "Instances of the Elastigroup lab"
  vpc_id      = module.vpc.vpc_id

  ingress_with_source_security_group_id = [{
    rule                     = "http-80-tcp"
    source_security_group_id = module.alb.security_group_id
  }]

  egress_rules = ["all-all"]
}
