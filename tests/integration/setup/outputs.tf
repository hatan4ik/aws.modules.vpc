output "name" {
  description = "Unique name of the VPC under test."
  value       = local.name
}

output "availability_zones" {
  description = "Two Availability Zone names of the caller's region, in the order the API lists them."
  value       = local.availability_zones
}

output "region" {
  description = "Region the VPC is created in, resolved from the caller's credentials."
  value       = data.aws_region.current.region
}

output "tags" {
  description = "Identifying tags applied to the VPC under test."
  value       = local.tags
}
