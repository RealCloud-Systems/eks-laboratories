output "ocean_id" {
  description = "ID of the Ocean cluster (o-...)."
  value       = module.ocean.ocean_id
}

output "vng_ids" {
  description = "IDs of the virtual node groups, by name."
  value       = { for k, v in module.vng : k => v.virtual_node_group_id }
}
