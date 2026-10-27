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

variable "app" {
  description = "App served by nginx on every instance."
  type = object({
    # Changing it changes the user data, which only reaches new instances (or all of them with a roll)
    version = optional(string, "v1")
  })
  default = {}
}

# Defaults are the baseline scenario; each file in scenarios/ only sets what it changes
variable "elastigroup" {
  description = "Elastigroup settings."
  type = object({
    # Capacity, scaling policies and tasks change desired_capacity until the next apply resets it
    min_size         = optional(number, 1)
    max_size         = optional(number, 4)
    desired_capacity = optional(number, 2)

    # Markets: ondemand_count, when set, replaces spot_percentage
    spot_percentage      = optional(number, 100)
    ondemand_count       = optional(number)
    orientation          = optional(string, "balanced")
    fallback_to_ondemand = optional(bool, true)
    revert_to_spot       = optional(string, "always") # always, never or timeWindow
    draining_timeout     = optional(number, 60)

    # Instance types, all with 2 vCPU so any of them fits the app
    instance_types_ondemand       = optional(string, "c6i.large")
    instance_types_spot           = optional(list(string), ["c5.large", "c5a.large", "c6i.large", "c6a.large", "c7i.large", "m5.large", "m6i.large", "m6a.large", "m7i.large"])
    instance_types_preferred_spot = optional(list(string))

    # Health check and auto healing (EC2, TARGET_GROUP, ...)
    health_check_type                                  = optional(string, "EC2")
    health_check_grace_period                          = optional(number, 120)
    health_check_unhealthy_duration_before_replacement = optional(number, 120)

    # 1 minute CloudWatch metrics, so scaling reacts faster (small extra AWS cost)
    enable_monitoring = optional(bool, false)

    # Target tracking scaling policy on the average CPU of the group
    scaling_target = optional(object({
      target   = optional(number, 50)
      cooldown = optional(number, 60)
    }))

    # Blue/green roll of every instance when the group changes
    roll = optional(object({
      enabled               = optional(bool, true)
      batch_size_percentage = optional(number, 50)
      grace_period          = optional(number, 180)
      health_check_type     = optional(string, "TARGET_GROUP")
    }))

    # Scheduled tasks, cron in UTC
    scheduled_tasks = optional(list(object({
      task_type             = string # scale, roll, ...
      cron_expression       = string
      is_enabled            = optional(bool, true)
      scale_target_capacity = optional(number)
      scale_min_capacity    = optional(number)
      scale_max_capacity    = optional(number)
      batch_size_percentage = optional(number)
    })), [])
  })
  default = {}

  validation {
    condition     = contains(["balanced", "costOriented", "availabilityOriented", "equalAzDistribution"], var.elastigroup.orientation)
    error_message = "orientation must be balanced, costOriented, availabilityOriented or equalAzDistribution."
  }
}

variable "fis" {
  description = "AWS FIS experiment that sends a Spot interruption notice to one instance of the Elastigroup."
  type = object({
    enabled = optional(bool, false)
    # How long before the interruption the notice is sent (ISO 8601), AWS requires at least 2 minutes
    notice_duration = optional(string, "PT2M")
  })
  default = {}
}
