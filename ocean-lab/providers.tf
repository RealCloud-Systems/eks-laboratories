provider "aws" {
  region  = local.region
  profile = local.profile

  default_tags {
    tags = local.tags
  }
}

provider "spotinst" {
  token   = var.spotinst_token
  account = var.spotinst_account
}

provider "helm" {
  kubernetes {
    host                   = local.cluster.endpoint
    cluster_ca_certificate = base64decode(local.cluster.ca_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", local.cluster.name, "--region", local.region, "--profile", local.profile]
    }
  }
}
