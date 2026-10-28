# Cluster-wide right sizing settings, the rules below build on them
resource "spotinst_ocean_right_sizing_cluster_config" "this" {
  count = var.right_sizing.enabled ? 1 : 0

  ocean_id           = module.ocean.ocean_id
  cluster_identifier = local.cluster.name

  config {
    adjust_limit_on_downsize          = false
    downside_only                     = false
    recommendations_cpu_percentile    = coalesce(var.right_sizing.cpu_percentile, 95)
    recommendations_memory_percentile = coalesce(var.right_sizing.memory_percentile, 95)
  }

  depends_on = [module.controller]
}

# Applies the right sizing recommendations by itself, instead of someone clicking "Start Optimizing"
# in the console. There is no terraform-aws-modules module for it, it is a Spot resource.
resource "spotinst_ocean_right_sizing_rule" "auto" {
  count = var.right_sizing.enabled ? 1 : 0

  ocean_id  = module.ocean.ocean_id
  rule_name = "${local.name}-auto"

  restart_replicas  = var.right_sizing.restart_replicas
  cpu_percentile    = var.right_sizing.cpu_percentile
  memory_percentile = var.right_sizing.memory_percentile

  # Policies: guardrails on what the rule is allowed to apply (scenario 10)
  downside_only                       = var.right_sizing.downside_only
  exclude_preliminary_recommendations = var.right_sizing.exclude_preliminary_recommendations

  dynamic "recommendation_application_hpa" {
    for_each = var.right_sizing.allow_hpa_recommendations != null ? [1] : []
    content {
      allow_hpa_recommendations = var.right_sizing.allow_hpa_recommendations
    }
  }

  dynamic "recommendation_application_boundaries" {
    for_each = var.right_sizing.boundaries[*]
    content {
      cpu_min    = recommendation_application_boundaries.value.cpu_min
      cpu_max    = recommendation_application_boundaries.value.cpu_max
      memory_min = recommendation_application_boundaries.value.memory_min
      memory_max = recommendation_application_boundaries.value.memory_max
    }
  }

  dynamic "recommendation_application_min_threshold" {
    for_each = var.right_sizing.min_threshold[*]
    content {
      cpu_percentage    = recommendation_application_min_threshold.value.cpu
      memory_percentage = recommendation_application_min_threshold.value.memory
    }
  }

  dynamic "recommendation_application_overhead_values" {
    for_each = var.right_sizing.overhead[*]
    content {
      cpu_percentage    = recommendation_application_overhead_values.value.cpu
      memory_percentage = recommendation_application_overhead_values.value.memory
    }
  }

  recommendation_application_intervals {
    repetition_basis = "WEEKLY"

    weekly_repetition_basis {
      interval_days             = var.right_sizing.days
      interval_hours_start_time = var.right_sizing.start_time
      interval_hours_end_time   = var.right_sizing.end_time
    }
  }

  # Every workload of these namespaces follows the rule
  auto_apply_definition {
    enabled    = true
    namespaces = var.right_sizing.namespaces
  }

  # The controller collects the usage, and applies the recommendations
  depends_on = [module.controller, spotinst_ocean_right_sizing_cluster_config.this]
}
