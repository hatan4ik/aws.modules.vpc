# Minimal private VPC

The smallest working call of `aws.modules.vpc`, and the shape the sandbox
network runs: a primary CIDR, one `private` tier with an explicit subnet per
Availability Zone, and the module's defaults for everything else. Those defaults
are deliberate: no internet gateway, NAT gateway, or endpoint exists until it is
declared, the VPC's default security group is managed as deny-all, VPC
Encryption Control is enforced, and flow logs capture all traffic to a
CloudWatch log group with one-year retention. The only addition is
`create_kms_key = true`, so the log group is encrypted with a customer-managed
key the module creates rather than AWS-managed encryption; the module's
`flow_logs_without_customer_key` check warns on every plan until a key is
created or supplied. Subnets and route tables are named `<name>-private-<az key>`
and tagged `Tier = private`, which is how the platform's other roots discover
them.

## Run

```sh
terraform init
terraform plan \
  -var cidr_block=10.64.0.0/16 \
  -var 'availability_zones={az1="us-east-2a",az2="us-east-2b"}' \
  -var 'private_subnet_cidrs={az1="10.64.0.0/20",az2="10.64.16.0/20"}'
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
| <a name="input_name"></a> [name](#input\_name) | VPC name; also the prefix of every subnet, route table, and flow-log resource name. | `string` | `"sandbox-network"` | no |
| <a name="input_private_subnet_cidrs"></a> [private\_subnet\_cidrs](#input\_private\_subnet\_cidrs) | IPv4 CIDR of each private subnet, keyed like availability\_zones. Both must lie inside cidr\_block. | <pre>object({<br/>    az1 = string<br/>    az2 = string<br/>  })</pre> | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | AWS region the VPC is created in. | `string` | `"us-east-2"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to every resource. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_flow_log_group_name"></a> [flow\_log\_group\_name](#output\_flow\_log\_group\_name) | CloudWatch log group that receives the VPC flow logs. |
| <a name="output_subnet_ids_by_tier"></a> [subnet\_ids\_by\_tier](#output\_subnet\_ids\_by\_tier) | Subnet IDs keyed by tier then AZ key. |
| <a name="output_vpc_id"></a> [vpc\_id](#output\_vpc\_id) | ID of the VPC. |
<!-- END_TF_DOCS -->
