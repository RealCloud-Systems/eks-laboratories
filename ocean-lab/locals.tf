locals {
  # General
  name    = "ocean-lab"
  region  = "us-east-1"
  profile = "services-admin"

  tags = {
    Project   = local.name
    ManagedBy = "terraform"
  }

  # Cluster created by eks-workshop
  eks = data.terraform_remote_state.eks.outputs
  cluster = {
    name             = local.eks.cluster_name
    version          = local.eks.cluster_version
    endpoint         = local.eks.cluster_endpoint
    ca_data          = local.eks.cluster_certificate_authority_data
    service_cidr     = local.eks.cluster_service_cidr
    subnet_ids       = local.eks.private_subnets
    security_groups  = local.eks.node_security_group_ids
    instance_profile = local.eks.ocean_node_instance_profile_arn
    system_nodes     = local.eks.system_node_selector
  }

  # AL2023 nodes join the cluster through nodeadm, not /etc/eks/bootstrap.sh
  user_data = <<-EOT
    MIME-Version: 1.0
    Content-Type: multipart/mixed; boundary="BOUNDARY"

    --BOUNDARY
    Content-Type: application/node.eks.aws

    ---
    apiVersion: node.eks.aws/v1alpha1
    kind: NodeConfig
    spec:
      cluster:
        name: ${local.cluster.name}
        apiServerEndpoint: ${local.cluster.endpoint}
        certificateAuthority: ${local.cluster.ca_data}
        cidr: ${local.cluster.service_cidr}

    --BOUNDARY--
  EOT
}
