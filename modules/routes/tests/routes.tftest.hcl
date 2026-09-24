mock_provider "aws" {}

variables {
  route_table_ids = {
    az1 = "rtb-0123456789abcdef0"
    az2 = "rtb-0123456789abcdef1"
  }
}

run "installs_every_route_into_every_table" {
  command = plan

  variables {
    routes = {
      to-hub    = { destination_cidr_block = "10.0.0.0/8", transit_gateway_id = "tgw-0123456789abcdef0" }
      to-corp   = { destination_prefix_list_id = "pl-0123456789abcdef0", transit_gateway_id = "tgw-0123456789abcdef0" }
      to-gwlb   = { destination_cidr_block = "192.168.0.0/16", vpc_endpoint_id = "vpce-0123456789abcdef0" }
      to-peer-6 = { destination_ipv6_cidr_block = "2001:db8::/32", vpc_peering_connection_id = "pcx-0123456789abcdef0" }
    }
  }

  assert {
    condition     = length(aws_route.this) == 8 && output.route_count == 8
    error_message = "Four routes across two tables must produce eight route resources."
  }

  assert {
    condition     = aws_route.this["az1/to-hub"].transit_gateway_id == "tgw-0123456789abcdef0" && aws_route.this["az1/to-hub"].destination_cidr_block == "10.0.0.0/8" && aws_route.this["az1/to-hub"].route_table_id == "rtb-0123456789abcdef0"
    error_message = "Transit Gateway routes must carry their destination and table."
  }

  assert {
    condition     = aws_route.this["az2/to-corp"].destination_prefix_list_id == "pl-0123456789abcdef0" && aws_route.this["az2/to-corp"].transit_gateway_id == "tgw-0123456789abcdef0" && aws_route.this["az1/to-gwlb"].vpc_endpoint_id == "vpce-0123456789abcdef0"
    error_message = "Prefix-list destinations and endpoint targets must pass through."
  }

  assert {
    condition     = aws_route.this["az1/to-peer-6"].destination_ipv6_cidr_block == "2001:db8::/32"
    error_message = "IPv6 destinations must pass through."
  }
}

run "no_routes_means_no_resources" {
  command = plan

  assert {
    condition     = length(aws_route.this) == 0 && output.route_count == 0
    error_message = "An empty routes map must create nothing."
  }
}

run "allows_default_route_when_the_tier_opts_in" {
  command = plan

  variables {
    allow_default_route = true
    routes = {
      internet = { destination_cidr_block = "0.0.0.0/0", nat_gateway_id = "nat-0123456789abcdef0" }
    }
  }

  assert {
    condition     = aws_route.this["az1/internet"].nat_gateway_id == "nat-0123456789abcdef0"
    error_message = "Default routes must be accepted when allowed."
  }
}

run "rejects_default_route_by_default" {
  command = plan

  variables {
    routes = {
      internet = { destination_cidr_block = "0.0.0.0/0", gateway_id = "igw-0123456789abcdef0" }
    }
  }

  expect_failures = [aws_route.this]
}

run "rejects_route_with_two_targets" {
  command = plan

  variables {
    routes = {
      bad = { destination_cidr_block = "10.0.0.0/8", transit_gateway_id = "tgw-0123456789abcdef0", nat_gateway_id = "nat-0123456789abcdef0" }
    }
  }

  expect_failures = [var.routes]
}

run "rejects_route_without_destination" {
  command = plan

  variables {
    routes = {
      bad = { transit_gateway_id = "tgw-0123456789abcdef0" }
    }
  }

  expect_failures = [var.routes]
}

run "rejects_malformed_route_table_id" {
  command = plan

  variables {
    route_table_ids = { az1 = "route-table-1" }
  }

  expect_failures = [var.route_table_ids]
}

run "rejects_endpoint_target_with_prefix_list_destination" {
  command = plan

  variables {
    routes = {
      bad = { destination_prefix_list_id = "pl-0123456789abcdef0", vpc_endpoint_id = "vpce-0123456789abcdef0" }
    }
  }

  expect_failures = [var.routes]
}
