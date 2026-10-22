# Scheduling: shutdown hours and a daily cluster roll. Times are UTC, edit them to a window
# a few minutes ahead before applying.
ocean = {
  shutdown_hours = {
    is_enabled   = true
    time_windows = ["Thu:18:30-Thu:23:00"]
  }
  tasks = [{
    is_enabled      = true
    cron_expression = "8 19 * * *"
    task_type       = "clusterRoll"
    parameters_cluster_roll = [{
      batch_size_percentage = 50
      respect_pdb           = true
      comment               = "ocean-lab scheduled roll"
    }]
  }]
}
