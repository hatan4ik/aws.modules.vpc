# Private workload VPC with IPAM, endpoints, and Transit Gateway routes

The workload pattern: the primary CIDR is allocated from an IPAM pool at apply
time, so both tiers carve their subnets from it with `newbits` and `netnum`
instead of literal CIDRs. The `private` tier holds the workloads, keeps one
route table per Availability Zone, and routes the hub network to a Transit
Gateway; the `transit` tier is two small subnets for the attachment that share
one route table. AWS APIs are reached without an internet path: interface
endpoints for ECR, CloudWatch Logs, and STS sit in the private subnets behind a
module-created security group that admits HTTPS from the VPC only, and an S3
gateway endpoint is associated with the route tables of both tiers. Flow logs
use a KMS key the platform already owns rather than one created here.

The Transit Gateway attachment itself, and the route on the hub side back to
this VPC, belong to the network account and are created outside this example.

## Run

```sh
terraform init
terraform plan \
  -var ipam_pool_id=ipam-pool-0123456789abcdef0 \
  -var ipam_netmask_length=20 \
  -var 'availability_zones={az1="us-east-2a",az2="us-east-2b"}' \
  -var transit_gateway_id=tgw-0123456789abcdef0 \
  -var hub_cidr_block=10.0.0.0/8 \
  -var flow_log_kms_key_arn=arn:aws:kms:us-east-2:123456789012:key/11111111-1111-1111-1111-111111111111
```

With a /20 allocation the private subnets are the first two /22 blocks and the
transit subnets the last two /26 blocks; the same proportions hold for any
allocation from /16 to /22.

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
| <a name="input_availability_zones"></a> [availability\_zones](#input\_availability\_zones) | Availability Zone of each subnet, keyed by the stable AZ keys (az1, az2) that name the subnets and route tables. Both tiers use the same zones. | <pre>object({<br/>    az1 = string<br/>    az2 = string<br/>  })</pre> | n/a | yes |
| <a name="input_flow_log_kms_key_arn"></a> [flow\_log\_kms\_key\_arn](#input\_flow\_log\_kms\_key\_arn) | ARN of an existing KMS key that encrypts the flow-log log group. Its policy must let logs.<region>.amazonaws.com use it for the group. | `string` | n/a | yes |
| <a name="input_hub_cidr_block"></a> [hub\_cidr\_block](#input\_hub\_cidr\_block) | IPv4 CIDR reached through the Transit Gateway, for example the enterprise 10.0.0.0/8. A default route is rejected because the tier does not set allow\_default\_route. | `string` | n/a | yes |
| <a name="input_ipam_netmask_length"></a> [ipam\_netmask\_length](#input\_ipam\_netmask\_length) | Prefix length of the allocated CIDR. The subnet layout carves quarters and 1/64 slices from it, so it must be /22 or larger. | `number` | n/a | yes |
| <a name="input_ipam_pool_id"></a> [ipam\_pool\_id](#input\_ipam\_pool\_id) | IPAM pool (ipam-pool-...) the primary CIDR is allocated from. The pool must be localized to region and shared with this account. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | VPC name; also the prefix of every subnet, route table, endpoint, and flow-log resource name. | `string` | `"orders-network"` | no |
| <a name="input_region"></a> [region](#input\_region) | AWS region the VPC is created in; also the region segment of every endpoint service name. | `string` | `"us-east-2"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to every resource. | `map(string)` | `{}` | no |
| <a name="input_transit_gateway_id"></a> [transit\_gateway\_id](#input\_transit\_gateway\_id) | Transit Gateway (tgw-...) the private tier routes hub traffic to. Its attachment to the transit subnets is created outside this example. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cidr_block"></a> [cidr\_block](#output\_cidr\_block) | Primary CIDR allocated from the IPAM pool; known after apply. |
| <a name="output_endpoint_security_group_id"></a> [endpoint\_security\_group\_id](#output\_endpoint\_security\_group\_id) | Security group attached to every interface endpoint; admits HTTPS from the VPC only. |
| <a name="output_gateway_endpoint_ids"></a> [gateway\_endpoint\_ids](#output\_gateway\_endpoint\_ids) | Gateway endpoint IDs keyed by endpoint key (s3). |
| <a name="output_interface_endpoint_ids"></a> [interface\_endpoint\_ids](#output\_interface\_endpoint\_ids) | Interface endpoint IDs keyed by endpoint key (ecr-api, ecr-dkr, logs, sts). |
| <a name="output_subnets"></a> [subnets](#output\_subnets) | Subnets keyed by tier then AZ key: id, arn, cidr\_block, availability\_zone, route\_table\_id. |
| <a name="output_vpc_id"></a> [vpc\_id](#output\_vpc\_id) | ID of the VPC. |
<!-- END_TF_DOCS -->
