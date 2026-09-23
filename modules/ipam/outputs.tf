output "ipam" {
  description = "IPAM identifiers and private scope owned by the Network account."
  value = {
    id                       = aws_vpc_ipam.this.id
    arn                      = aws_vpc_ipam.this.arn
    private_default_scope_id = aws_vpc_ipam.this.private_default_scope_id
    home_region              = var.home_region
  }
}

output "regional_pools" {
  description = "Approved regional IPAM pool IDs/ARNs and their RAM-share status for reviewed workload-root configuration."
  value = {
    for key, pool in aws_vpc_ipam_pool.regional : key => {
      id                     = pool.id
      arn                    = pool.arn
      locale                 = pool.locale
      cidr                   = aws_vpc_ipam_pool_cidr.regional[key].cidr
      ram_resource_share_arn = try(aws_ram_resource_share.regional_pool[key].arn, null)
    }
  }
}
