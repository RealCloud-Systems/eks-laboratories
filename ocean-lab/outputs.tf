output "ocean_id" {
  description = "ID of the Ocean cluster (o-...)."
  value       = module.ocean.ocean_id
}

output "vng_ids" {
  description = "IDs of the virtual node groups, by name."
  value       = { for k, v in module.vng : k => v.virtual_node_group_id }
}

output "fis_experiment_template_id" {
  description = "FIS experiment template that interrupts an Ocean node (only with fis.enabled)."
  value       = one(aws_fis_experiment_template.spot_interruption[*].id)
}
