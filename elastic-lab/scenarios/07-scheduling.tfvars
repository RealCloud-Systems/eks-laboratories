# Scheduling: scale the group to 0 and back 2 hours later, on a cron. Times are UTC: before applying,
# set the scale down a few minutes ahead and keep the scale up at least 2 hours after it.
elastigroup = {
  scheduled_tasks = [
    {
      task_type             = "scale"
      cron_expression       = "0 19 * * *" # every day at 19:00 UTC
      scale_target_capacity = 0
      scale_min_capacity    = 0
      scale_max_capacity    = 4
    },
    {
      task_type             = "scale"
      cron_expression       = "0 21 * * *" # every day at 21:00 UTC, 2 hours later
      scale_target_capacity = 2
      scale_min_capacity    = 1
      scale_max_capacity    = 4
    },
  ]
}
