# Sandbox network module

Creates the narrow, isolated first network slice in the existing sandbox AWS
account. It accepts a direct CIDR allocation rather than IPAM because the
organization-wide IPAM hierarchy is a later Control Tower/TGW decision.

The module creates a DNS-enabled VPC, two or more private subnets, intentionally
empty private route tables, a deny-all default security group, VPC encryption
control, and VPC Flow Logs to a customer-KMS-encrypted CloudWatch Logs group. It deliberately does not create
an internet gateway, NAT gateway, public subnets, VPC endpoints, Transit Gateway
attachments, or application resources.

The KMS key is dedicated to this VPC's flow logs; the Terraform state KMS key
is never reused for observability data.

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
| [aws_default_security_group.deny_all](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/default_security_group) | resource |
| [aws_flow_log.vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/flow_log) | resource |
| [aws_iam_role.flow_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.flow_logs_delivery](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_kms_alias.flow_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_key.flow_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_route_table.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table_association.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_subnet.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_vpc.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc) | resource |
| [aws_vpc_encryption_control.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_encryption_control) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_availability_zones"></a> [availability\_zones](#input\_availability\_zones) | Stable subnet key to available AWS Availability Zone name mapping. | `map(string)` | n/a | yes |
| <a name="input_flow_log_retention_in_days"></a> [flow\_log\_retention\_in\_days](#input\_flow\_log\_retention\_in\_days) | CloudWatch Logs retention period for VPC flow logs; security baseline requires at least one year. | `number` | `365` | no |
| <a name="input_name"></a> [name](#input\_name) | Stable name for the isolated sandbox network. | `string` | n/a | yes |
| <a name="input_private_subnet_cidrs"></a> [private\_subnet\_cidrs](#input\_private\_subnet\_cidrs) | Stable subnet key to private IPv4 CIDR mapping. Keys must match availability\_zones, enforced by the VPC precondition. | `map(string)` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Allocation, ownership, and traceability tags applied to all taggable resources. | `map(string)` | `{}` | no |
| <a name="input_vpc_cidr"></a> [vpc\_cidr](#input\_vpc\_cidr) | IPv4 CIDR explicitly allocated to this sandbox VPC. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_flow_logs"></a> [flow\_logs](#output\_flow\_logs) | VPC Flow Logs identifiers for observability configuration. |
| <a name="output_private_subnets"></a> [private\_subnets](#output\_private\_subnets) | Private subnet IDs and placement keyed by stable subnet name. |
| <a name="output_vpc"></a> [vpc](#output\_vpc) | VPC identifiers and CIDR available for separately reviewed attachments. |
<!-- END_TF_DOCS -->
