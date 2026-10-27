# There is no terraform-aws-modules module for it, it is a Spot resource
resource "spotinst_elastigroup_aws" "this" {
  name        = local.name
  description = "Elastigroup lab: nginx behind an ALB"
  product     = "Linux/UNIX"
  region      = local.region

  # Private subnets, one per AZ, as "<az>:<subnet id>"
  availability_zones = [for i, id in module.vpc.private_subnets : "${local.azs[i]}:${id}"]

  # Capacity
  min_size         = var.elastigroup.min_size
  max_size         = var.elastigroup.max_size
  desired_capacity = var.elastigroup.desired_capacity
  capacity_unit    = "instance"

  # Launch configuration
  image_id             = nonsensitive(data.aws_ssm_parameter.ami.value)
  iam_instance_profile = module.instance_role.instance_profile_arn
  security_groups      = [module.app_sg.security_group_id]
  user_data            = local.user_data
  enable_monitoring    = var.elastigroup.enable_monitoring
  ebs_optimized        = true

  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  # Markets: Spot rejects spot_percentage and ondemand_count together
  instance_types_ondemand       = var.elastigroup.instance_types_ondemand
  instance_types_spot           = var.elastigroup.instance_types_spot
  instance_types_preferred_spot = var.elastigroup.instance_types_preferred_spot
  spot_percentage               = var.elastigroup.ondemand_count == null ? var.elastigroup.spot_percentage : null
  ondemand_count                = var.elastigroup.ondemand_count
  orientation                   = var.elastigroup.orientation
  fallback_to_ondemand          = var.elastigroup.fallback_to_ondemand
  draining_timeout              = var.elastigroup.draining_timeout
  utilize_reserved_instances    = false

  revert_to_spot {
    perform_at = var.elastigroup.revert_to_spot
  }

  # Load balancer and auto healing
  target_group_arns = [module.alb.target_groups["app"].arn]

  health_check_type                                  = var.elastigroup.health_check_type
  health_check_grace_period                          = var.elastigroup.health_check_grace_period
  health_check_unhealthy_duration_before_replacement = var.elastigroup.health_check_unhealthy_duration_before_replacement

  # Scaling
  dynamic "scaling_target_policy" {
    for_each = var.elastigroup.scaling_target[*]

    content {
      policy_name = "cpu-target"
      source      = "cloudWatch"
      namespace   = "AWS/EC2"
      metric_name = "CPUUtilization"
      statistic   = "average"
      unit        = "percent"
      target      = scaling_target_policy.value.target
      cooldown    = scaling_target_policy.value.cooldown
    }
  }

  # Scheduling
  dynamic "scheduled_task" {
    for_each = var.elastigroup.scheduled_tasks

    content {
      task_type             = scheduled_task.value.task_type
      cron_expression       = scheduled_task.value.cron_expression
      is_enabled            = scheduled_task.value.is_enabled
      scale_target_capacity = scheduled_task.value.scale_target_capacity
      scale_min_capacity    = scheduled_task.value.scale_min_capacity
      scale_max_capacity    = scheduled_task.value.scale_max_capacity
      batch_size_percentage = scheduled_task.value.batch_size_percentage
    }
  }

  # Roll: without it, changes only reach new instances
  update_policy {
    should_roll            = try(var.elastigroup.roll.enabled, false)
    should_resume_stateful = false
    auto_apply_tags        = true

    dynamic "roll_config" {
      for_each = try(var.elastigroup.roll.enabled, false) ? [var.elastigroup.roll] : []

      content {
        batch_size_percentage = roll_config.value.batch_size_percentage
        grace_period          = roll_config.value.grace_period
        health_check_type     = roll_config.value.health_check_type

        strategy {
          action = "REPLACE_SERVER"
        }
      }
    }
  }

  dynamic "tags" {
    for_each = local.instance_tags

    content {
      key   = tags.key
      value = tags.value
    }
  }

  # desired_capacity is not ignored on purpose: every apply brings the group back to the scenario's capacity
  resource_tag_specification {
    should_tag_volumes = true
    should_tag_enis    = true
  }
}
