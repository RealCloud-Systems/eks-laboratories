module "instance_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role"
  version = "~> 6.0"

  name            = "${local.name}-instance"
  use_name_prefix = false
  description     = "Role for the instances launched by the Elastigroup lab"

  trust_policy_permissions = {
    EC2AssumeRole = {
      actions = ["sts:AssumeRole"]
      principals = [{
        type        = "Service"
        identifiers = ["ec2.amazonaws.com"]
      }]
    }
  }

  # Session Manager and Run Command, used to reach the instances and to stress them in the scenarios
  policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  create_instance_profile = true
}
