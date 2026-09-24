# The partition is an input; the data source is a fallback so the RAM
# permission ARN needs no lookup when the caller already knows it.
data "aws_partition" "current" {
  count = var.partition == null ? 1 : 0
}

locals {
  partition = var.partition != null ? var.partition : data.aws_partition.current[0].partition

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
