# Credentials come from TF_VAR_spotinst_token / TF_VAR_spotinst_account
variable "spotinst_token" {
  description = "Spot (Flexera) API token."
  type        = string
  sensitive   = true
}

variable "spotinst_account" {
  description = "Spot (Flexera) account ID (act-...)."
  type        = string
}

# Defaults are the baseline scenario; each file in scenarios/ only sets what it changes
variable "ocean" {
  description = "Ocean cluster settings."
  type = object({
    # Capacity guardrails, keep the lab cheap
    min_size       = optional(number, 0)
    max_size       = optional(number, 10)
    max_vcpu       = optional(number, 64)
    max_memory_gib = optional(number, 256)

    # Strategy
    spot_percentage                  = optional(number, 100) # default for VNGs that don't set one
    fallback_to_ondemand             = optional(bool, true)
    availability_vs_cost             = optional(string, "balanced")
    spread_nodes_by                  = optional(string, "count")
    draining_timeout                 = optional(number, 120)
    max_replacement_limit_percentage = optional(number, 10)

    # Instance selection (whitelist and blacklist are mutually exclusive)
    whitelist = optional(list(string))
    blacklist = optional(list(string))
    filters = optional(object({
      architectures           = optional(list(string))
      categories              = optional(list(string))
      disk_types              = optional(list(string))
      exclude_families        = optional(list(string))
      exclude_metal           = optional(bool)
      hypervisor              = optional(list(string))
      include_families        = optional(list(string))
      is_ena_supported        = optional(bool)
      max_gpu                 = optional(number)
      min_gpu                 = optional(number)
      max_memory_gib          = optional(number)
      max_network_performance = optional(number)
      max_vcpu                = optional(number)
      min_enis                = optional(number)
      min_memory_gib          = optional(number)
      min_network_performance = optional(number)
      min_vcpu                = optional(number)
      root_device_types       = optional(list(string))
      virtualization_types    = optional(list(string))
    }))

    # Autoscaler and headroom
    autoscale_is_enabled                 = optional(bool, true)
    autoscale_is_auto_config             = optional(bool, true)
    auto_headroom_percentage             = optional(number, 5)
    enable_automatic_and_manual_headroom = optional(bool)
    cpu_per_unit                         = optional(number, 0)
    memory_per_unit                      = optional(number, 0)
    num_of_unit                          = optional(number, 0)
    autoscale_cooldown                   = optional(number)
    is_aggressive_scale_down_enabled     = optional(bool)
    max_scale_down_percentage            = optional(number, 10)

    # Roll on config changes
    should_roll                  = optional(bool, false)
    conditioned_roll             = optional(bool)
    batch_size_percentage        = optional(number, 20)
    batch_min_healthy_percentage = optional(number)
    respect_pdb                  = optional(bool, true)

    # Launch template
    root_volume_size = optional(number, 30)

    # Scheduling, passed through as the module expects them
    shutdown_hours       = optional(any)
    optimization_windows = optional(any)
    tasks                = optional(any)
  })
  default = {}

  validation {
    condition     = contains(["costOriented", "balanced", "cheapest"], var.ocean.availability_vs_cost)
    error_message = "availability_vs_cost must be costOriented, balanced or cheapest."
  }
}

variable "vngs" {
  description = "Virtual node groups, keyed by name."
  type = map(object({
    arch                     = optional(string, "x86_64")
    instance_types           = optional(list(string))
    labels                   = optional(map(string), {})
    taints                   = optional(list(object({ key = string, value = string, effect = string })))
    spot_percentage          = optional(number)
    availability_vs_cost     = optional(string)
    min_instance_count       = optional(number)
    max_instance_count       = optional(number)
    auto_headroom_percentage = optional(number)
    restrict_scale_down      = optional(bool)
  }))
  default = {
    general = {}
  }

  validation {
    condition     = alltrue([for v in values(var.vngs) : contains(["x86_64", "arm64"], v.arch)])
    error_message = "arch must be x86_64 or arm64."
  }
}

variable "controller" {
  description = "Ocean controller settings."
  type = object({
    chart_version         = optional(string, "0.1.77")
    disable_rightsizing   = optional(bool, true)
    deploy_metrics_server = optional(bool, false)
  })
  default = {}
}

variable "fis" {
  description = "AWS FIS experiment that sends a Spot interruption notice to the Ocean nodes."
  type = object({
    enabled = optional(bool, false)
    # How long before the interruption the notice is sent (ISO 8601), AWS requires at least 2 minutes
    notice_duration = optional(string, "PT2M")
  })
  default = {}
}

variable "right_sizing" {
  description = "Automatic right sizing: a rule that applies the recommendations to the workloads on a schedule."
  type = object({
    enabled    = optional(bool, false)
    namespaces = optional(list(string), ["default"])
    # MORE_THAN_ONE_REPLICA, ALL_MANIFEST, NO_RESTART or IN_PLACE_OR_RECREATE
    restart_replicas = optional(string, "MORE_THAN_ONE_REPLICA")
    # Weekly window in which the recommendations can be applied (HH:MM)
    days       = optional(list(string), ["SUNDAY", "MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY"])
    start_time = optional(string, "00:00")
    end_time   = optional(string, "23:59")
    # Percentile used to calculate the recommendations, null keeps the Ocean default
    cpu_percentile    = optional(number)
    memory_percentile = optional(number)

    # Policies of the rule, null keeps the Ocean default
    downside_only                       = optional(bool) # only lowers requests, never raises them
    exclude_preliminary_recommendations = optional(bool) # ignores recommendations with less than 4 days of data
    allow_hpa_recommendations           = optional(bool) # also applies to workloads with an HPA
    # Lowest and highest requests the rule can apply, CPU in vCPU and memory in GiB
    boundaries = optional(object({
      cpu_min    = optional(number)
      cpu_max    = optional(number)
      memory_min = optional(number)
      memory_max = optional(number)
    }))
    # Minimum change for a recommendation to be applied, as a fraction (0.1 = 10%)
    min_threshold = optional(object({
      cpu    = optional(number)
      memory = optional(number)
    }))
    # Margin added on top of the recommendation, as a fraction (0.2 = 20%)
    overhead = optional(object({
      cpu    = optional(number)
      memory = optional(number)
    }))
  })
  default = {}
}
