# Bring your own flow-log key and log group

Substitutes the flow-log resources the module would normally create with ones
the caller already owns: `create_log_group = false` with `log_group_arn` points
the flow log at an existing CloudWatch log group, and `kms_key_arn` names the
key that group is encrypted with. The module then creates only the delivery
role, scoped to that group, and the flow log itself; it never modifies the
supplied group or key, and `flow_log_group_name` and `flow_log_kms_key_arn` are
reported exactly as supplied so consumers see the same outputs a managed
configuration gives. Use this when a central logging setup owns the group and
the key, or when migrating a VPC whose log destination must not change. The
example also associates `secondary_cidr_blocks` with the VPC while keeping its
subnets in the primary range.

The supplied key's policy must already allow `logs.<region>.amazonaws.com` to
use it for the group; the module's created key (see `examples/minimal`) shows
the statement that grants this.

## Run

```sh
terraform init
terraform plan \
  -var cidr_block=10.64.0.0/16 \
  -var 'secondary_cidr_blocks=["100.64.0.0/16"]' \
  -var 'availability_zones={az1="us-east-2a",az2="us-east-2b"}' \
  -var 'private_subnet_cidrs={az1="10.64.0.0/20",az2="10.64.16.0/20"}' \
  -var flow_log_group_arn=arn:aws:logs:us-east-2:123456789012:log-group:/platform/network/flow-logs \
  -var flow_log_group_name=/platform/network/flow-logs \
  -var flow_log_kms_key_arn=arn:aws:kms:us-east-2:123456789012:key/11111111-1111-1111-1111-111111111111
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.7.0, < 2.0.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.35.0, < 7.0.0 |

## Providers

No providers.

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_vpc"></a> [vpc](#module\_vpc) | ../../ | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_availability_zones"></a> [availability\_zones](#input\_availability\_zones) | Availability Zone of each private subnet, keyed by the stable AZ keys (az1, az2) that name the subnets and route tables. | <pre>object({<br/>    az1 = string<br/>    az2 = string<br/>  })</pre> | n/a | yes |
| <a name="input_cidr_block"></a> [cidr\_block](#input\_cidr\_block) | Primary IPv4 CIDR of the VPC, for example 10.64.0.0/16. | `string` | n/a | yes |
| <a name="input_flow_log_group_arn"></a> [flow\_log\_group\_arn](#input\_flow\_log\_group\_arn) | ARN of the existing CloudWatch log group that receives the flow logs. The delivery role is scoped to this group. | `string` | n/a | yes |
| <a name="input_flow_log_group_name"></a> [flow\_log\_group\_name](#input\_flow\_log\_group\_name) | Name of that log group, reported through the flow\_log\_group\_name output for consumers that address the group by name. | `string` | n/a | yes |
| <a name="input_flow_log_kms_key_arn"></a> [flow\_log\_kms\_key\_arn](#input\_flow\_log\_kms\_key\_arn) | ARN of the KMS key the log group is encrypted with, reported through the flow\_log\_kms\_key\_arn output. The module does not change the group's encryption. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | VPC name; also the prefix of every subnet, route table, and flow-log resource name. | `string` | `"orders-network"` | no |
| <a name="input_private_subnet_cidrs"></a> [private\_subnet\_cidrs](#input\_private\_subnet\_cidrs) | IPv4 CIDR of each private subnet, keyed like availability\_zones. Both must lie inside cidr\_block. | <pre>object({<br/>    az1 = string<br/>    az2 = string<br/>  })</pre> | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | AWS region the VPC is created in; the log group must be in the same region. | `string` | `"us-east-2"` | no |
| <a name="input_secondary_cidr_blocks"></a> [secondary\_cidr\_blocks](#input\_secondary\_cidr\_blocks) | Additional IPv4 CIDR blocks associated with the VPC. They must not overlap cidr\_block or each other. | `set(string)` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to every resource. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_flow_log_group_name"></a> [flow\_log\_group\_name](#output\_flow\_log\_group\_name) | Log group the flow logs are written to, exactly as supplied. |
| <a name="output_flow_log_id"></a> [flow\_log\_id](#output\_flow\_log\_id) | ID of the flow log delivering to the supplied log group. |
| <a name="output_flow_log_kms_key_arn"></a> [flow\_log\_kms\_key\_arn](#output\_flow\_log\_kms\_key\_arn) | Key the log group is encrypted with, exactly as supplied. |
| <a name="output_flow_log_role_arn"></a> [flow\_log\_role\_arn](#output\_flow\_log\_role\_arn) | ARN of the delivery role the module created for the supplied log group. |
| <a name="output_secondary_cidr_blocks"></a> [secondary\_cidr\_blocks](#output\_secondary\_cidr\_blocks) | Secondary CIDR blocks associated with the VPC, sorted. |
| <a name="output_vpc_id"></a> [vpc\_id](#output\_vpc\_id) | ID of the VPC. |
<!-- END_TF_DOCS -->
