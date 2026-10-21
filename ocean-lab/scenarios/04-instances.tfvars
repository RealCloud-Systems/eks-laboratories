# Instance selection: cheapest market choice, plus an arm64 (Graviton) VNG.
ocean = {
  availability_vs_cost = "cheapest"
  filters = {
    exclude_metal    = true
    exclude_families = ["t*"] # every burstable family, including future ones
    # cheapest alone picked an inf1 (Inferentia), keep to regular instance categories
    categories = ["General_purpose", "Compute_optimized", "Memory_optimized"]
  }
}

vngs = {
  general = {}
  arm64 = {
    arch           = "arm64"
    instance_types = ["m7g.large", "m7g.xlarge", "c7g.large", "c7g.xlarge", "m6g.large", "c6g.large"]
  }
}
