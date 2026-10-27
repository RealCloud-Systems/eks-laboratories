# Markets: one On-Demand instance is always kept, the rest is Spot, preferring the newer families.
# The new mix only applies to new launches: after applying, `mise run roll` replaces the running instances.
elastigroup = {
  ondemand_count                = 1
  instance_types_preferred_spot = ["c7i.large", "m7i.large"]
}
