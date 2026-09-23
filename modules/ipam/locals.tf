data "aws_partition" "current" {}

locals {
  common_tags = merge(var.tags, {
    Name      = var.name
    Component = "network-ipam"
  })

  ram_principal_associations = merge([
    for pool_key, pool in var.regional_pools : {
      for principal in pool.ram_principals :
      "${pool_key}:${principal}" => {
        pool_key  = pool_key
        principal = principal
      }
    }
  ]...)
}
