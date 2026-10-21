# Manual headroom: keep room for 2 pods of 1 vCPU / 1.5 GiB on top of the automatic %.
# Combining both requires autoscale_is_auto_config = true (the default).
ocean = {
  enable_automatic_and_manual_headroom = true
  cpu_per_unit                         = 1000 # millicores
  memory_per_unit                      = 1536 # MiB
  num_of_unit                          = 2
}
