output "elastigroup_id" {
  description = "ID of the Elastigroup (sig-...)."
  value       = spotinst_elastigroup_aws.this.id
}

output "app_url" {
  description = "URL of the app, through the ALB."
  value       = "http://${module.alb.dns_name}"
}

output "target_group_arn" {
  description = "Target group the Elastigroup registers its instances in."
  value       = module.alb.target_groups["app"].arn
}

output "fis_experiment_template_id" {
  description = "FIS experiment template that interrupts an Elastigroup instance (only with fis.enabled)."
  value       = one(aws_fis_experiment_template.spot_interruption[*].id)
}
