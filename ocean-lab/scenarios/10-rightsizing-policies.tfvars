# Right sizing policies: the automatic rule of 09-rightsizing-auto with guardrails on what it can
# apply. oversized uses almost nothing, so the boundaries are what decide its new requests.
controller = {
  disable_rightsizing   = false
  deploy_metrics_server = true
}

right_sizing = {
  enabled          = true
  namespaces       = ["default"]
  restart_replicas = "MORE_THAN_ONE_REPLICA"
  start_time       = "00:00"
  end_time         = "23:59"

  downside_only                       = true  # only lowers requests, an increase is left for a human
  exclude_preliminary_recommendations = false # true waits 4 days of data, too long for the lab
  allow_hpa_recommendations           = false # leaves workloads with an HPA alone

  # Never below 250m / 256 MiB, never above 1 vCPU / 2 GiB
  boundaries = {
    cpu_min    = 0.25
    cpu_max    = 1
    memory_min = 0.25
    memory_max = 2
  }

  # Ignores recommendations that change the requests by less than 10%
  min_threshold = {
    cpu    = 0.1
    memory = 0.1
  }

  # Applies the recommendation plus 20%, room for usage peaks
  overhead = {
    cpu    = 0.2
    memory = 0.2
  }
}
