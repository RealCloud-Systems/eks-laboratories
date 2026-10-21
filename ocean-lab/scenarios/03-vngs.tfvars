# Workload isolation through VNGs: general (Spot), batch (Spot, tainted), critical (On-Demand only).
vngs = {
  general = {}
  batch = {
    taints = [{ key = "ocean-lab/batch", value = "true", effect = "NoSchedule" }]
  }
  critical = {
    spot_percentage = 0
  }
}
