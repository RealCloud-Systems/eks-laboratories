output "vpc_id" {
  description = "ID of the VPC."
  value       = module.vpc.vpc_id
}

output "private_subnets" {
  description = "IDs of the private subnets (where nodes run)."
  value       = module.vpc.private_subnets
}

output "public_subnets" {
  description = "IDs of the public subnets."
  value       = module.vpc.public_subnets
}

output "cluster_name" {
  description = "Name of the EKS cluster."
  value       = module.eks.cluster_name
}

output "configure_kubectl" {
  description = "Command to configure kubectl for the cluster."
  value       = "aws eks update-kubeconfig --region ${local.region} --name ${module.eks.cluster_name}"
}

output "cluster_endpoint" {
  description = "Endpoint of the EKS API server."
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded CA certificate of the cluster."
  value       = module.eks.cluster_certificate_authority_data
}

output "cluster_service_cidr" {
  description = "CIDR block Kubernetes services get IPs from."
  value       = module.eks.cluster_service_cidr
}

output "cluster_version" {
  description = "Kubernetes version of the cluster."
  value       = local.eks.cluster_version
}

output "node_security_group_ids" {
  description = "Security groups worker nodes need (node SG + cluster primary SG)."
  value       = [module.eks.node_security_group_id, module.eks.cluster_primary_security_group_id]
}

output "ocean_node_instance_profile_arn" {
  description = "Instance profile for nodes launched by Ocean."
  value       = module.ocean_node_role.instance_profile_arn
}

output "system_node_selector" {
  description = "Node selector that pins pods to the managed node group (e.g. the Ocean controller)."
  value       = { "eks.amazonaws.com/nodegroup" = split(":", module.eks.eks_managed_node_groups["default"].node_group_id)[1] }
}
