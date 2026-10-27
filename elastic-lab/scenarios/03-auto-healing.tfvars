# Auto healing: the target group health check decides when an instance is replaced.
elastigroup = {
  health_check_type                                  = "TARGET_GROUP"
  health_check_grace_period                          = 120
  health_check_unhealthy_duration_before_replacement = 60
}
