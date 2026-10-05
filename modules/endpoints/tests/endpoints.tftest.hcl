mock_provider "aws" {}

variables {
  vpc_id          = "vpc-0123456789abcdef0"
  name            = "sandbox-network-dev"
  vpc_cidr_blocks = ["10.64.0.0/16"]
  tags            = { Environment = "dev" }
}

run "creates_interface_and_gateway_endpoints_with_a_locked_down_group" {
  command = plan

  variables {
    interface_endpoints = {
      ecr-api = { service_name = "com.amazonaws.us-east-2.ecr.api", subnet_ids = ["subnet-0123456789abcdef0", "subnet-0123456789abcdef1"] }
      logs    = { service_name = "com.amazonaws.us-east-2.logs", subnet_ids = ["subnet-0123456789abcdef0"], private_dns_enabled = false, policy_json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}" }
    }
    gateway_endpoints = {
      s3 = { service_name = "com.amazonaws.us-east-2.s3", route_table_ids = ["rtb-0123456789abcdef0", "rtb-0123456789abcdef1"] }
    }
  }

  assert {
    # A test's module.<name> reference exposes only that module's declared
    # outputs, never its internal resources, so the actual rendered security
    # group and rule are verified in aws.modules.security-group's own test
    # suite. What this module owns and can assert here is that it calls that
    # module with the right name and the right ingress_rules content.
    condition     = local.security_group_name == "sandbox-network-dev-interface-endpoints" && length(local.https_ingress_rules) == 1 && local.https_ingress_rules["0"].cidr_ipv4 == "10.64.0.0/16" && local.https_ingress_rules["0"].from_port == 443 && length(module.security_group.ingress_rule_ids) == 1 && contains(keys(module.security_group.ingress_rule_ids), "0")
    error_message = "The endpoint security group must be named for this VPC and admit HTTPS from the VPC CIDR only."
  }

  assert {
    condition     = length(aws_vpc_endpoint.interface) == 2 && aws_vpc_endpoint.interface["ecr-api"].vpc_endpoint_type == "Interface" && aws_vpc_endpoint.interface["ecr-api"].private_dns_enabled == true && aws_vpc_endpoint.interface["logs"].private_dns_enabled == false && aws_vpc_endpoint.interface["ecr-api"].tags["Name"] == "sandbox-network-dev-ecr-api"
    error_message = "Interface endpoints must render with private DNS defaults and platform names."
  }

  assert {
    condition     = aws_vpc_endpoint.gateway["s3"].vpc_endpoint_type == "Gateway" && length(aws_vpc_endpoint.gateway["s3"].route_table_ids) == 2 && aws_vpc_endpoint.gateway["s3"].service_name == "com.amazonaws.us-east-2.s3"
    error_message = "Gateway endpoints must associate with every given route table."
  }

  assert {
    condition     = length(output.security_group_ids) == 1 && length(output.interface_endpoint_ids) == 2 && length(output.gateway_endpoint_ids) == 1
    error_message = "Outputs must expose the group and endpoint IDs by key."
  }
}

run "uses_supplied_security_groups_only" {
  command = plan

  variables {
    create_security_group = false
    security_group_ids    = ["sg-0bbbbbbbbbbbbbbbb", "sg-0aaaaaaaaaaaaaaaa"]
    interface_endpoints = {
      sts = { service_name = "com.amazonaws.us-east-2.sts", subnet_ids = ["subnet-0123456789abcdef0"] }
    }
  }

  assert {
    condition     = output.security_group_id == null && output.security_group_ids == tolist(["sg-0aaaaaaaaaaaaaaaa", "sg-0bbbbbbbbbbbbbbbb"]) && aws_vpc_endpoint.interface["sts"].security_group_ids == toset(["sg-0aaaaaaaaaaaaaaaa", "sg-0bbbbbbbbbbbbbbbb"])
    error_message = "Supplied groups must be used verbatim, sorted, with no managed group."
  }
}

run "renders_dns_options_when_requested" {
  command = plan

  variables {
    interface_endpoints = {
      ssm = { service_name = "com.amazonaws.us-east-2.ssm", subnet_ids = ["subnet-0123456789abcdef0"], ip_address_type = "ipv4", dns_record_ip_type = "ipv4" }
    }
  }

  assert {
    condition     = aws_vpc_endpoint.interface["ssm"].dns_options[0].dns_record_ip_type == "ipv4" && aws_vpc_endpoint.interface["ssm"].ip_address_type == "ipv4"
    error_message = "DNS options must render only when set."
  }
}

run "creates_nothing_when_no_endpoints_are_declared" {
  command = plan

  assert {
    condition     = length(aws_vpc_endpoint.interface) == 0 && length(aws_vpc_endpoint.gateway) == 0 && local.create_security_group == false && output.security_group_id == null && length(output.security_group_ids) == 0
    error_message = "Empty endpoint maps must create no endpoints and no security group."
  }
}

run "gateway_only_creates_no_security_group" {
  command = plan

  variables {
    gateway_endpoints = {
      s3 = { service_name = "com.amazonaws.us-east-2.s3", route_table_ids = ["rtb-0123456789abcdef0"] }
    }
  }

  assert {
    condition     = length(aws_vpc_endpoint.gateway) == 1 && local.create_security_group == false && length(local.https_ingress_rules) == 0 && output.security_group_id == null
    error_message = "Gateway endpoints take no security group, so a gateway-only configuration must not create one."
  }
}

run "explicit_create_security_group_still_creates_the_group_without_interface_endpoints" {
  command = plan

  variables {
    create_security_group = true
    gateway_endpoints = {
      s3 = { service_name = "com.amazonaws.us-east-2.s3", route_table_ids = ["rtb-0123456789abcdef0"] }
    }
  }

  assert {
    condition     = local.create_security_group == true && length(local.https_ingress_rules) == 1 && length(module.security_group.ingress_rule_ids) == 1
    error_message = "create_security_group = true must create the group regardless of the endpoint maps."
  }
}

run "null_description_selects_the_single_default" {
  command = plan

  variables {
    security_group_description = null
    interface_endpoints = {
      sts = { service_name = "com.amazonaws.us-east-2.sts", subnet_ids = ["subnet-0123456789abcdef0"] }
    }
  }

  assert {
    condition     = var.security_group_description == "Permits private HTTPS connections from this VPC to its AWS interface endpoints."
    error_message = "A null description (what the root passes when its caller sets none) must select this module's default."
  }
}

run "rejects_interface_endpoint_without_any_security_group" {
  command = plan

  variables {
    create_security_group = false
    interface_endpoints = {
      sts = { service_name = "com.amazonaws.us-east-2.sts", subnet_ids = ["subnet-0123456789abcdef0"] }
    }
  }

  expect_failures = [aws_vpc_endpoint.interface]
}

run "rejects_created_group_without_vpc_cidrs" {
  command = plan

  variables {
    vpc_cidr_blocks = []
    interface_endpoints = {
      sts = { service_name = "com.amazonaws.us-east-2.sts", subnet_ids = ["subnet-0123456789abcdef0"] }
    }
  }

  expect_failures = [terraform_data.security_group_inputs]
}

run "rejects_non_aws_service_name" {
  command = plan

  variables {
    interface_endpoints = {
      bad = { service_name = "example.com/service", subnet_ids = ["subnet-0123456789abcdef0"] }
    }
  }

  expect_failures = [var.interface_endpoints]
}

run "rejects_gateway_endpoint_without_route_tables" {
  command = plan

  variables {
    gateway_endpoints = {
      s3 = { service_name = "com.amazonaws.us-east-2.s3", route_table_ids = [] }
    }
  }

  expect_failures = [var.gateway_endpoints]
}
