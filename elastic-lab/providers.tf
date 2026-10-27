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
