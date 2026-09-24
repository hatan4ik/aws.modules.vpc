output "route_ids" {
  description = "Route IDs keyed by <route table key>/<route key>."
  value       = { for key, route in aws_route.this : key => route.id }
}

output "route_count" {
  description = "Number of routes installed (route tables x routes)."
  value       = length(local.entries)
}
