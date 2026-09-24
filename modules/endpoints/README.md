# endpoints

Owns VPC endpoints: interface (PrivateLink) endpoints placed in the subnets you name, gateway endpoints (S3, DynamoDB) associated with the route tables you name, and the security group that fronts the interface endpoints. It is a separate module because endpoint sets grow and change independently of the VPC, because the endpoint security group has its own reviewers, and because endpoints are frequently added to a VPC that was created elsewhere.

## Usage

```hcl
module "endpoints" {
  source = "git::https://github.com/hatan4ik/aws.modules.vpc.git//modules/endpoints?ref=<commit-sha>" # v1.0.0

  vpc_id          = "vpc-0123456789abcdef0"
  name            = "sandbox-network-dev"
  vpc_cidr_blocks = ["10.64.0.0/16"]

  interface_endpoints = {
    ecr-api = { service_name = "com.amazonaws.us-east-2.ecr.api", subnet_ids = values(module.private.subnet_ids) }
    ecr-dkr = { service_name = "com.amazonaws.us-east-2.ecr.dkr", subnet_ids = values(module.private.subnet_ids) }
    logs    = { service_name = "com.amazonaws.us-east-2.logs", subnet_ids = values(module.private.subnet_ids), private_dns_enabled = false }
  }

  gateway_endpoints = {
    s3 = { service_name = "com.amazonaws.us-east-2.s3", route_table_ids = values(module.private.route_table_ids) }
  }

  tags = { Environment = "dev" }
}
```

## Behaviour

- One HTTPS-only security group. With `create_security_group = true` (the default) the module creates `<name>-interface-endpoints` (or `security_group_name`) with one `aws_vpc_security_group_ingress_rule` per entry of `vpc_cidr_blocks` for TCP 443 and no egress rules. Rules are standalone resources, so adding a CIDR adds one rule and nothing else changes. `vpc_cidr_blocks` must list at least one CIDR when the group is created; a precondition on the group says so.
- Rules keyed by position. The ingress rules are `https["0"]`, `https["1"]`, and so on, in the order of `vpc_cidr_blocks`, and are tagged `Name = <group name>-https-<index>`. `vpc_cidr_blocks` is a list rather than a set so that an IPAM-allocated CIDR, unknown until apply, still yields known instance keys at plan time. Keep the list order stable; reordering it re-creates rules.
- Supplied groups. `security_group_ids` are attached to every interface endpoint in sorted order after the created group. With `create_security_group = false` they are the only groups, `security_group_id` is null, and an interface endpoint with no group at all is rejected at plan time. `security_group_description` is immutable on the group; changing it replaces the group.
- Private DNS is on by default. Each interface endpoint has `private_dns_enabled = true` unless it says otherwise, so `sts.us-east-2.amazonaws.com` resolves to the endpoint inside the VPC. `dns_record_ip_type` and `private_dns_only_for_inbound_resolver_endpoint` render a `dns_options` block only when set; `ip_address_type` is `ipv4`, `ipv6`, or `dualstack`.
- Service names are passed in full: `com.amazonaws.<region>.<service>` or `aws.<service>` for interface endpoints, `com.amazonaws.<region>.<service>` for gateway endpoints. The module never infers a region. Every interface endpoint needs at least one subnet and every gateway endpoint at least one route table.
- Names and outputs. Endpoints are tagged `Name = <name>-<key>`; keys are 1 to 63 characters of letters, digits, underscores, dots, or hyphens (`ecr.api` and `ecr-api` are both fine). Outputs are keyed the same way: `interface_endpoint_ids`, `interface_endpoint_dns_entries`, `gateway_endpoint_ids`, and `gateway_endpoint_prefix_list_ids` (the managed prefix list of each gateway endpoint, for security-group egress rules), plus `security_group_id` and the full `security_group_ids` list.
- Empty endpoint maps create only the security group. Set `create_security_group = false` as well if you want the module to create nothing.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.7.0, < 2.0.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.35.0, < 7.0.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 6.35.0, < 7.0.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_security_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_vpc_endpoint.gateway](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [aws_vpc_endpoint.interface](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [aws_vpc_security_group_ingress_rule.https](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_create_security_group"></a> [create\_security\_group](#input\_create\_security\_group) | Create the interface-endpoint security group (HTTPS from vpc\_cidr\_blocks, no egress). | `bool` | `true` | no |
| <a name="input_gateway_endpoints"></a> [gateway\_endpoints](#input\_gateway\_endpoints) | Gateway endpoints (S3, DynamoDB) keyed by a stable identifier, associated with the given route tables. | <pre>map(object({<br/>    service_name    = string<br/>    route_table_ids = set(string)<br/>    policy_json     = optional(string)<br/>  }))</pre> | `{}` | no |
| <a name="input_interface_endpoints"></a> [interface\_endpoints](#input\_interface\_endpoints) | Interface (PrivateLink) endpoints keyed by a stable identifier. service\_name is the full AWS service name so the module never infers a Region. | <pre>map(object({<br/>    service_name                                   = string<br/>    subnet_ids                                     = set(string)<br/>    private_dns_enabled                            = optional(bool, true)<br/>    policy_json                                    = optional(string)<br/>    ip_address_type                                = optional(string)<br/>    dns_record_ip_type                             = optional(string)<br/>    private_dns_only_for_inbound_resolver_endpoint = optional(bool)<br/>  }))</pre> | `{}` | no |
| <a name="input_name"></a> [name](#input\_name) | VPC name; endpoints are named <name>-<key> and the endpoint security group <name>-interface-endpoints. | `string` | n/a | yes |
| <a name="input_security_group_description"></a> [security\_group\_description](#input\_security\_group\_description) | Description of the created security group. Changing it replaces the group. | `string` | `"Permits private HTTPS connections from this VPC to its AWS interface endpoints."` | no |
| <a name="input_security_group_ids"></a> [security\_group\_ids](#input\_security\_group\_ids) | Additional security groups attached to every interface endpoint, or the only groups when create\_security\_group is false. | `set(string)` | `[]` | no |
| <a name="input_security_group_name"></a> [security\_group\_name](#input\_security\_group\_name) | Name of the created security group. Defaults to <name>-interface-endpoints. | `string` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to every endpoint and the security group; Name is added by the module. | `map(string)` | `{}` | no |
| <a name="input_vpc_cidr_blocks"></a> [vpc\_cidr\_blocks](#input\_vpc\_cidr\_blocks) | CIDR blocks allowed to reach interface endpoints over HTTPS through the created security group (normally the VPC CIDRs). A list, so an IPAM-allocated CIDR that is unknown until apply is accepted. | `list(string)` | `[]` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC the endpoints belong to. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_gateway_endpoint_ids"></a> [gateway\_endpoint\_ids](#output\_gateway\_endpoint\_ids) | Gateway endpoint IDs keyed by endpoint key. |
| <a name="output_gateway_endpoint_prefix_list_ids"></a> [gateway\_endpoint\_prefix\_list\_ids](#output\_gateway\_endpoint\_prefix\_list\_ids) | Managed prefix list IDs of gateway endpoints keyed by endpoint key, for security-group egress rules. |
| <a name="output_interface_endpoint_dns_entries"></a> [interface\_endpoint\_dns\_entries](#output\_interface\_endpoint\_dns\_entries) | DNS entries of each interface endpoint keyed by endpoint key. |
| <a name="output_interface_endpoint_ids"></a> [interface\_endpoint\_ids](#output\_interface\_endpoint\_ids) | Interface endpoint IDs keyed by endpoint key. |
| <a name="output_security_group_id"></a> [security\_group\_id](#output\_security\_group\_id) | ID of the created interface-endpoint security group, or null. |
| <a name="output_security_group_ids"></a> [security\_group\_ids](#output\_security\_group\_ids) | Every security group attached to interface endpoints. |
<!-- END_TF_DOCS -->
