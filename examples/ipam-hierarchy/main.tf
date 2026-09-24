# The IPAM and its pools belong to the delegated Network account, which the
# default provider represents. Delegating that account is an AWS Organizations
# action, so it runs with credentials for the management account through the
# aliased provider. Both operate in the IPAM home Region: AWS accepts pool RAM
# shares only there.
provider "aws" {
  region = var.region
}

provider "aws" {
  alias  = "management"
  region = var.region

  assume_role {
    role_arn = var.management_role_arn
  }
}

module "ipam_organization_admin" {
  source = "../../modules/ipam-organization-admin"

  providers = { aws = aws.management }

  delegated_admin_account_id = var.network_account_id
  tags                       = var.tags
}

# A non-allocating enterprise pool holds the whole private range; VPCs allocate
# only from the Regional child pools, which are RAM-shared to the accounts or
# organizational units listed in ram_principals.
module "ipam" {
  source = "../../modules/ipam"

  name              = var.name
  home_region       = var.region
  operating_regions = var.operating_regions
  top_level_cidr    = var.top_level_cidr
  regional_pools    = var.regional_pools
  tags              = var.tags

  depends_on = [module.ipam_organization_admin]
}
