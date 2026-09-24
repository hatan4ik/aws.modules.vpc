# Advisory checks: they warn on every plan and apply but never block. Each
# names a configuration that is valid yet usually unintended.

check "single_az" {
  assert {
    condition     = length(local.single_az_tiers) == 0
    error_message = "One or more tiers have a single subnet. Spread every tier across at least two Availability Zones for resilience."
  }
}

check "flow_logs_disabled" {
  assert {
    condition     = local.flow_logs_enabled
    error_message = "VPC Flow Logs are disabled. Network evidence will not be captured for this VPC."
  }
}

check "flow_logs_without_customer_key" {
  assert {
    condition     = !local.flow_logs_enabled ? true : (var.flow_logs.destination.type != "cloud-watch-logs" || !var.flow_logs.destination.create_log_group || var.flow_logs.destination.kms_key_arn != null || var.flow_logs.destination.create_kms_key)
    error_message = "The flow-log log group uses AWS-managed encryption. Set flow_logs.destination.kms_key_arn or create_kms_key for a customer-managed key."
  }
}

check "internet_path_declared" {
  assert {
    condition     = !local.internet_enabled
    error_message = "This VPC declares an internet gateway or NAT gateways. Confirm the network design allows an internet path for these tiers."
  }
}
