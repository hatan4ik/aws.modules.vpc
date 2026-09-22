# terraform-aws-vpc-workload

Creates one private, IPAM-allocated workload VPC with two or more explicitly keyed private subnets, no Internet gateway or NAT route, encrypted VPC Flow Logs, gateway/interface endpoints, a deny-all default security group, and VPC Encryption Control in enforce mode.

The caller supplies all variable values, endpoint service names, KMS key ARN, and retention decision. The module does not contain a provider block, remote-state reference, account ID, or public subnet. See ADR 0003 and ADR 0008.

The Phase 6 module-release workflow checks that the generated `terraform-docs` section below is current.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.7.0, < 2.0.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.35.0, < 7.0.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.65.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_log_group.flow_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_default_security_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/default_security_group) | resource |
| [aws_flow_log.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/flow_log) | resource |
| [aws_iam_role.flow_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.flow_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_route_table.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table_association.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_security_group.interface_endpoints](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_subnet.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_vpc.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc) | resource |
| [aws_vpc_encryption_control.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_encryption_control) | resource |
| [aws_vpc_endpoint.gateway](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [aws_vpc_endpoint.interface](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_availability_zones"></a> [availability\_zones](#input\_availability\_zones) | Stable AZ-keyed private-subnet allocation plan. Each netnum is evaluated against the VPC CIDR allocated by IPAM. | <pre>map(object({<br/>    availability_zone = string<br/>    subnet_newbits    = number<br/>    subnet_netnum     = number<br/>  }))</pre> | n/a | yes |
| <a name="input_flow_log_kms_key_arn"></a> [flow\_log\_kms\_key\_arn](#input\_flow\_log\_kms\_key\_arn) | Customer-managed KMS key ARN used to encrypt the VPC Flow Logs CloudWatch log group. | `string` | n/a | yes |
| <a name="input_flow_log_retention_in_days"></a> [flow\_log\_retention\_in\_days](#input\_flow\_log\_retention\_in\_days) | Approved CloudWatch retention period for VPC Flow Logs. | `number` | n/a | yes |
| <a name="input_gateway_endpoints"></a> [gateway\_endpoints](#input\_gateway\_endpoints) | Stable endpoint-keyed gateway endpoint services and optional restrictive endpoint policies. | <pre>map(object({<br/>    service_name = string<br/>    policy_json  = optional(string)<br/>  }))</pre> | `{}` | no |
| <a name="input_interface_endpoints"></a> [interface\_endpoints](#input\_interface\_endpoints) | Stable endpoint-keyed AWS PrivateLink services. Service names are passed explicitly so the module does not infer a Region. | <pre>map(object({<br/>    service_name        = string<br/>    private_dns_enabled = bool<br/>    policy_json         = optional(string)<br/>  }))</pre> | `{}` | no |
| <a name="input_ipv4_ipam_pool_id"></a> [ipv4\_ipam\_pool\_id](#input\_ipv4\_ipam\_pool\_id) | Approved AWS VPC IPAM pool from which AWS allocates the VPC CIDR. | `string` | n/a | yes |
| <a name="input_ipv4_netmask_length"></a> [ipv4\_netmask\_length](#input\_ipv4\_netmask\_length) | IPv4 prefix length AWS VPC IPAM allocates to this VPC. | `number` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Lowercase workload VPC name used in resource names and tags. | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Additional required allocation and ownership tags. Name and Component tags are computed by the module. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_flow_log"></a> [flow\_log](#output\_flow\_log) | VPC flow-log ID and encrypted CloudWatch log group ARN. |
| <a name="output_gateway_endpoint_ids"></a> [gateway\_endpoint\_ids](#output\_gateway\_endpoint\_ids) | Stable endpoint-keyed gateway endpoint IDs. |
| <a name="output_interface_endpoint_ids"></a> [interface\_endpoint\_ids](#output\_interface\_endpoint\_ids) | Stable endpoint-keyed interface endpoint IDs. |
| <a name="output_interface_endpoint_security_group_id"></a> [interface\_endpoint\_security\_group\_id](#output\_interface\_endpoint\_security\_group\_id) | Security group ID applied to interface endpoints. |
| <a name="output_private_subnets"></a> [private\_subnets](#output\_private\_subnets) | Stable AZ-keyed private subnet IDs, CIDRs, and route table IDs for workload composition. |
| <a name="output_vpc"></a> [vpc](#output\_vpc) | The workload VPC identifiers and IPAM-assigned CIDR required by attachment and service modules. |
<!-- END_TF_DOCS -->
