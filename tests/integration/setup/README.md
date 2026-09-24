# Integration fixtures

Disposable inputs for the integration suites in the parent directory: two
Availability Zone names and the region resolved from the caller's credentials,
and a unique VPC name with a random suffix. The module under test creates every
network resource itself, so this fixture holds no AWS resource; `terraform
test` resolves it in the caller's own account before the module is applied. It
is not a deployable pattern and is excluded from policy scans (see
`.checkov.yml` and `trivy.yaml` at the repository root).

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.7.0, < 2.0.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.35.0, < 7.0.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.6.0, < 4.0.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 6.35.0, < 7.0.0 |
| <a name="provider_random"></a> [random](#provider\_random) | >= 3.6.0, < 4.0.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [random_id.suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | Prefix of the VPC name under test; a random suffix is appended so concurrent runs never collide. The flow-log role and KMS alias inherit it, which is what the integration IAM policy is scoped to. | `string` | `"vpc-it"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to the VPC under test in addition to the identifying defaults. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_availability_zones"></a> [availability\_zones](#output\_availability\_zones) | Two Availability Zone names of the caller's region, in the order the API lists them. |
| <a name="output_name"></a> [name](#output\_name) | Unique name of the VPC under test. |
| <a name="output_region"></a> [region](#output\_region) | Region the VPC is created in, resolved from the caller's credentials. |
| <a name="output_tags"></a> [tags](#output\_tags) | Identifying tags applied to the VPC under test. |
<!-- END_TF_DOCS -->
