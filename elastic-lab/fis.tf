# Role FIS assumes to interrupt the Spot instances launched by the Elastigroup
module "fis_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role"
  version = "~> 6.0"

  create = var.fis.enabled

  name            = "${local.name}-fis"
  use_name_prefix = false
  description     = "Role for AWS FIS to interrupt the Spot instances of the Elastigroup lab"

  trust_policy_permissions = {
    FISAssumeRole = {
      actions = ["sts:AssumeRole"]
      principals = [{
        type        = "Service"
        identifiers = ["fis.amazonaws.com"]
      }]
    }
  }

  create_inline_policy = true
  inline_policy_permissions = {
    SpotInterruption = {
      actions   = ["ec2:SendSpotInstanceInterruptions"]
      resources = ["arn:aws:ec2:${local.region}:${data.aws_caller_identity.current.account_id}:instance/*"]
    }
    DescribeInstances = {
      actions   = ["ec2:DescribeInstances"]
      resources = ["*"]
    }
  }
}

# There is no terraform-aws-modules module for FIS
resource "aws_fis_experiment_template" "spot_interruption" {
  count = var.fis.enabled ? 1 : 0

  description = "Interrupt one Spot instance of the Elastigroup"
  role_arn    = module.fis_role.arn

  # No stop condition: the experiment only sends a notice and ends on its own
  stop_condition {
    source = "none"
  }

  action {
    name      = "interrupt"
    action_id = "aws:ec2:send-spot-instance-interruptions"

    parameter {
      key   = "durationBeforeInterruption"
      value = var.fis.notice_duration
    }

    target {
      key   = "SpotInstances"
      value = "elastigroup-instances"
    }
  }

  # Only Spot instances of this Elastigroup, one at a time
  target {
    name           = "elastigroup-instances"
    resource_type  = "aws:ec2:spot-instance"
    selection_mode = "COUNT(1)"

    resource_tag {
      key   = "elastic-lab/group"
      value = local.name
    }
  }

  tags = {
    Name = "${local.name}-spot-interruption"
  }
}
