module "ocean" {
  source  = "spotinst/ocean-aws-k8s/spotinst"
  version = "1.13.0"

  # Cluster, its name is also the controller identifier
  cluster_name = local.cluster.name
  region       = local.region
  subnet_ids   = local.cluster.subnet_ids

  # Launch template, VNGs inherit whatever they don't override
  ami_id                      = nonsensitive(data.aws_ssm_parameter.ami["x86_64"].value)
  user_data                   = local.user_data
  worker_instance_profile_arn = local.cluster.instance_profile
  security_groups             = local.cluster.security_groups
  root_volume_size            = var.ocean.root_volume_size
  http_tokens                 = "required"
  http_put_response_hop_limit = 2 # lets pods reach IMDS through the node
  should_tag_volumes          = true
  use_as_template_only        = true # every node comes from a VNG

  # Capacity
  min_size         = var.ocean.min_size
  max_size         = var.ocean.max_size
  desired_capacity = var.ocean.min_size
  max_vcpu         = var.ocean.max_vcpu
  max_memory_gib   = var.ocean.max_memory_gib

  # Strategy, spot_percentage lives on the VNGs: Spot rejects it on both levels
  fallback_to_ondemand             = var.ocean.fallback_to_ondemand
  availability_vs_cost             = var.ocean.availability_vs_cost
  spread_nodes_by                  = var.ocean.spread_nodes_by
  draining_timeout                 = var.ocean.draining_timeout
  max_replacement_limit_percentage = var.ocean.max_replacement_limit_percentage
  utilize_reserved_instances       = false

  # Instance selection
  whitelist = var.ocean.whitelist
  blacklist = var.ocean.blacklist
  filters   = var.ocean.filters

  # Autoscaler and headroom
  autoscale_is_enabled                 = var.ocean.autoscale_is_enabled
  autoscale_is_auto_config             = var.ocean.autoscale_is_auto_config
  auto_headroom_percentage             = var.ocean.auto_headroom_percentage
  enable_automatic_and_manual_headroom = var.ocean.enable_automatic_and_manual_headroom
  cpu_per_unit                         = var.ocean.cpu_per_unit
  memory_per_unit                      = var.ocean.memory_per_unit
  num_of_unit                          = var.ocean.num_of_unit
  autoscale_cooldown                   = var.ocean.autoscale_cooldown
  is_aggressive_scale_down_enabled     = var.ocean.is_aggressive_scale_down_enabled
  max_scale_down_percentage            = var.ocean.max_scale_down_percentage

  # Roll
  should_roll                  = var.ocean.should_roll
  conditioned_roll             = var.ocean.conditioned_roll
  batch_size_percentage        = var.ocean.batch_size_percentage
  batch_min_healthy_percentage = var.ocean.batch_min_healthy_percentage
  respect_pdb                  = var.ocean.respect_pdb

  # Scheduling
  shutdown_hours       = var.ocean.shutdown_hours
  optimization_windows = var.ocean.optimization_windows
  tasks                = var.ocean.tasks

  tags = {
    Name = "${local.cluster.name}-ocean-node"
  }
}

module "vng" {
  source   = "spotinst/ocean-aws-k8s-vng/spotinst"
  version  = "0.24.0"
  for_each = var.vngs

  name     = each.key
  ocean_id = module.ocean.ocean_id

  # Only arm64 needs its own image, everything else is inherited from the Ocean template
  image_id       = each.value.arch == "arm64" ? nonsensitive(data.aws_ssm_parameter.ami["arm64"].value) : null
  instance_types = each.value.instance_types

  labels = [for k, v in merge({ "ocean-lab/vng" = each.key }, each.value.labels) : { key = k, value = v }]
  taints = each.value.taints

  spot_percentage          = coalesce(each.value.spot_percentage, var.ocean.spot_percentage)
  availability_vs_cost     = coalesce(each.value.availability_vs_cost, var.ocean.availability_vs_cost)
  min_instance_count       = each.value.min_instance_count
  max_instance_count       = each.value.max_instance_count
  auto_headroom_percentage = each.value.auto_headroom_percentage
  restrict_scale_down      = each.value.restrict_scale_down

  # The module sends false by default, which would override the cluster's value.
  # max_scale_down_percentage stays null: Spot rejects it on both the cluster and the VNG.
  is_aggressive_scale_down_enabled = coalesce(var.ocean.is_aggressive_scale_down_enabled, false)

  # The module defaults differ from the Ocean template, keep them aligned
  root_volume_size            = var.ocean.root_volume_size
  draining_timeout            = null # inherit from the cluster; on a VNG Spot requires >= 300
  http_tokens                 = "required"
  http_put_response_hop_limit = 2
  utilize_reserved_instances  = false

  # Terminate the VNG's nodes when it's removed, nothing is left running after a scenario
  delete_nodes = true
  force_delete = true
}
