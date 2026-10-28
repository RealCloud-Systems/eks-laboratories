# Scaling: target tracking on the average CPU of the group, with 1 minute metrics.
# Detailed monitoring only applies to new launches: after applying, `mise run roll` replaces the running instances.
elastigroup = {
  enable_monitoring = true
  scaling_target = {
    target   = 50
    cooldown = 60
  }
}
