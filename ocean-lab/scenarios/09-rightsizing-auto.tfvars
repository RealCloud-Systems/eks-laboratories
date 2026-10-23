# Automatic right sizing: same controller settings as 09-rightsizing, plus a rule that applies
# the recommendations to the workloads of the default namespace without anyone using the console.
controller = {
  disable_rightsizing   = false
  deploy_metrics_server = true
}

right_sizing = {
  enabled          = true
  namespaces       = ["default"]
  restart_replicas = "MORE_THAN_ONE_REPLICA" # restarts only workloads with more than 1 replica
  # Window in which the recommendations can be applied, every day all day for the lab
  start_time = "00:00"
  end_time   = "23:59"
}
