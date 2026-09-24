# flow-logs

Owns VPC Flow Log delivery for one VPC: the flow log itself and, for a CloudWatch destination, the log group, the delivery role with its scoped inline policy, and optionally a customer-managed KMS key. It is a separate module because log delivery has its own reviewers (retention, encryption, key policy), because a caller may bring a central key or log group, and because flow logs are often turned on for a VPC that was created elsewhere. The layout, names, and policies are those of the v0.1.x sandbox-network root, so that root migrates with `moved` blocks only.

## Usage

```hcl
module "flow_logs" {
  source = "git::https://github.com/hatan4ik/aws.modules.vpc.git//modules/flow-logs?ref=<commit-sha>" # v1.0.0

  name   = "sandbox-network-dev"
  vpc_id = "vpc-0123456789abcdef0"

  destination       = { create_kms_key = true }
  retention_in_days = 365

  # Optional. Without these the module reads them from the provider.
  partition  = "aws"
  region     = "us-east-2"
  account_id = "123456789012"

  tags = { Environment = "dev" }
}
```

## Behaviour

- Created versus supplied key. `destination.create_kms_key = true` creates a rotated key `<name>-flow-logs` (alias `alias/<name>-flow-logs`, tagged `DataClass = network-observability`, deletion window `kms_key_deletion_window_in_days`, 7 to 30) whose policy has two statements: `kms:*` for the account root and `Decrypt`, `DescribeKey`, `Encrypt`, `GenerateDataKey*`, `ReEncrypt*` for `logs.<region>.amazonaws.com` conditioned on `kms:EncryptionContext:aws:logs:arn` equal to this log group's ARN. `destination.kms_key_arn` uses a key you manage instead and creates none; its policy must admit the same service principal for the same log group. The two are mutually exclusive, and with neither the log group uses AWS-managed encryption.
- The log-group ARN is constructed, not read. The key policy must name the log group's ARN before the group exists (the group is encrypted with the key, so the key comes first), and the delivery policy's resource is `<log-group-arn>:*`. The ARN is therefore built as `arn:<partition>:logs:<region>:<account_id>:log-group:<log_group_name>` from inputs. This is also why `log_group_arn` is an output even before apply.
- Data-source fallback. `partition`, `region`, and `account_id` are inputs. Each one that is null is read from `aws_partition`, `aws_region`, or `aws_caller_identity` (each data source exists only when its input is missing). Pass all three to keep plans free of API reads; the root's contract tests do, and this module's tests supply `mock_data` for the fallback.
- Existing log group. `destination.create_log_group = false` with `destination.log_group_arn` delivers to a group you manage; no group is created, and the role is scoped to that ARN. `destination.log_group_name` renames the created group (default `/aws/vpc/<name>/flow-logs`); `log_group_class` is `STANDARD` or `INFREQUENT_ACCESS`. Retention accepts only CloudWatch values of 365 days or more.
- S3 mode. `destination.type = "s3"` with `destination.s3_bucket_arn` (a bucket ARN, optionally with a prefix) creates no log group, no role, and no key; `iam_role_arn` is null on the flow log and the CloudWatch outputs are null. `destination.s3_options` sets `file_format` (`plain-text` or `parquet`), `hive_compatible_partitions`, and `per_hour_partition`. The bucket policy that admits `delivery.logs.amazonaws.com` is yours.
- Names. The flow log is `<name>-all-traffic`; the log group `/aws/vpc/<name>/flow-logs` (its `Name` tag is the same string); the role `<name>-vpc-flow-logs` (or `role_name`, with `role_path` and `role_permissions_boundary`) trusting `vpc-flow-logs.amazonaws.com` only; its inline policy `<name>-flow-logs-delivery` grants `logs:CreateLogStream`, `logs:DescribeLogStreams`, and `logs:PutLogEvents` on `<log-group-arn>:*`.
- Capture. `traffic_type` is `ALL`, `ACCEPT`, or `REJECT` (default `ALL`); `max_aggregation_interval` is 60 or 600 seconds (default 60); `log_format` replaces the default record fields when set. The flow log depends on the role policy, so delivery never starts before the permission exists.

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
| [aws_cloudwatch_log_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_flow_log.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/flow_log) | resource |
| [aws_iam_role.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_kms_alias.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_key.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_account_id"></a> [account\_id](#input\_account\_id) | Account ID used in constructed ARNs and the key policy. Resolved from the provider when null. | `string` | `null` | no |
| <a name="input_destination"></a> [destination](#input\_destination) | Where flow logs go. cloud-watch-logs (default) creates an encrypted log group, or uses an existing one when create\_log\_group is false and log\_group\_arn is given; s3 delivers to s3\_bucket\_arn (bucket ARN, optionally with a prefix) and needs no role. | <pre>object({<br/>    type             = optional(string, "cloud-watch-logs")<br/>    log_group_name   = optional(string)<br/>    create_log_group = optional(bool, true)<br/>    log_group_arn    = optional(string)<br/>    log_group_class  = optional(string, "STANDARD")<br/>    kms_key_arn      = optional(string)<br/>    create_kms_key   = optional(bool, false)<br/>    s3_bucket_arn    = optional(string)<br/>    s3_options = optional(object({<br/>      file_format                = optional(string, "plain-text")<br/>      hive_compatible_partitions = optional(bool, false)<br/>      per_hour_partition         = optional(bool, false)<br/>    }))<br/>  })</pre> | `{}` | no |
| <a name="input_kms_key_deletion_window_in_days"></a> [kms\_key\_deletion\_window\_in\_days](#input\_kms\_key\_deletion\_window\_in\_days) | Deletion window of the created KMS key. | `number` | `30` | no |
| <a name="input_log_format"></a> [log\_format](#input\_log\_format) | Custom flow log record format. Null keeps the AWS default fields. | `string` | `null` | no |
| <a name="input_max_aggregation_interval"></a> [max\_aggregation\_interval](#input\_max\_aggregation\_interval) | Capture window in seconds: 60 or 600. | `number` | `60` | no |
| <a name="input_name"></a> [name](#input\_name) | VPC name; the log group is /aws/vpc/<name>/flow-logs, the delivery role <name>-vpc-flow-logs, the created key alias <name>-flow-logs. | `string` | n/a | yes |
| <a name="input_partition"></a> [partition](#input\_partition) | AWS partition used in constructed ARNs. Resolved from the provider when null. | `string` | `null` | no |
| <a name="input_region"></a> [region](#input\_region) | Region used in constructed ARNs and the CloudWatch Logs service principal. Resolved from the provider when null. | `string` | `null` | no |
| <a name="input_retention_in_days"></a> [retention\_in\_days](#input\_retention\_in\_days) | Retention of the created log group. Network evidence is kept for at least one year. | `number` | `365` | no |
| <a name="input_role_name"></a> [role\_name](#input\_role\_name) | Name of the delivery role for CloudWatch destinations. Defaults to <name>-vpc-flow-logs. | `string` | `null` | no |
| <a name="input_role_path"></a> [role\_path](#input\_role\_path) | IAM path of the delivery role. | `string` | `"/"` | no |
| <a name="input_role_permissions_boundary"></a> [role\_permissions\_boundary](#input\_role\_permissions\_boundary) | Permissions boundary policy ARN for the delivery role. | `string` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to the key, log group, role, and flow log; Name is added by the module. | `map(string)` | `{}` | no |
| <a name="input_traffic_type"></a> [traffic\_type](#input\_traffic\_type) | Traffic to capture: ALL, ACCEPT, or REJECT. | `string` | `"ALL"` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC whose traffic is logged. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_arn"></a> [arn](#output\_arn) | Flow log ARN. |
| <a name="output_destination_type"></a> [destination\_type](#output\_destination\_type) | cloud-watch-logs or s3. |
| <a name="output_id"></a> [id](#output\_id) | Flow log ID. |
| <a name="output_kms_key_alias_arn"></a> [kms\_key\_alias\_arn](#output\_kms\_key\_alias\_arn) | ARN of the created key alias, else null. |
| <a name="output_kms_key_arn"></a> [kms\_key\_arn](#output\_kms\_key\_arn) | KMS key encrypting the log group (created or supplied), else null. |
| <a name="output_log_group_arn"></a> [log\_group\_arn](#output\_log\_group\_arn) | CloudWatch log group ARN for cloud-watch-logs destinations, else null. |
| <a name="output_log_group_name"></a> [log\_group\_name](#output\_log\_group\_name) | CloudWatch log group name for cloud-watch-logs destinations, else null. |
| <a name="output_role_arn"></a> [role\_arn](#output\_role\_arn) | Delivery role ARN for cloud-watch-logs destinations, else null. |
| <a name="output_role_name"></a> [role\_name](#output\_role\_name) | Delivery role name for cloud-watch-logs destinations, else null. |
<!-- END_TF_DOCS -->
