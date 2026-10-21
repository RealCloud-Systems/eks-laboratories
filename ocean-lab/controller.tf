module "controller" {
  source  = "spotinst/kubernetes-controller/ocean"
  version = "0.0.32"

  spotinst_token     = var.spotinst_token
  spotinst_account   = var.spotinst_account
  cluster_identifier = local.cluster.name

  chart_version         = var.controller.chart_version
  disable_rightsizing   = var.controller.disable_rightsizing
  deploy_metrics_server = var.controller.deploy_metrics_server

  # Keep the controller on the managed node group, off the Spot nodes it scales
  node_selector = local.cluster.system_nodes

  # The Ocean cluster must exist before the controller registers with it
  depends_on = [module.ocean]
}
