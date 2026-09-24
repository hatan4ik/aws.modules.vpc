# Integration suites

The suites in this directory apply the module for real in **your** AWS account
and destroy everything afterwards. They complement the contract tests in
`tests/`, which run with `mock_provider`, need no credentials, and use the AWS
documentation account `123456789012`, fixed Availability Zone names, and fake
IDs on purpose: they prove the module's interface, CIDR arithmetic, route
resolution, and rendering, not that AWS accepts it. These suites prove the
latter.

Nothing here is tied to an account, region, or landing zone. Credentials and
the region come from the environment; the fixture in [`setup/`](setup/)
resolves two Availability Zones of that region and a random-suffixed name, so
concurrent runs never collide. The module creates every network resource
itself, so the fixture holds no AWS resource.

| Suite | What it proves | Costs | Needs | Typical time |
| --- | --- | --- | --- | --- |
| `smoke.tftest.hcl` | The defaults survive the real API: a private-only VPC with VPC Encryption Control enforced, the deny-all default security group, two private subnets derived with `newbits` and `netnum`, per-AZ route tables, an S3 gateway endpoint with its managed prefix list, and flow logs to a CloudWatch log group under a customer-managed key with the module's role and names. | Nothing while it runs. The KMS key lingers pending deletion for 7 days, unusable and free of charge. | credentials, region | about 4 minutes |
| `nat-egress.tftest.hcl` | A real internet path: public and private tiers, an internet gateway, one public NAT gateway in `public/az1`, the public default route through the gateway and the private default route through the NAT gateway, both resolved from keys to IDs, with flow logs under a customer-managed key. | A NAT gateway and an Elastic IP for the minutes they exist, a few cents. Same 7-day KMS pending deletion. | credentials, region | about 8 minutes |

The `nat-egress` suite sets `vpc_encryption_control = "monitor"`: enforce mode
rejects the unencrypted internet path the suite deliberately declares. The
`smoke` suite keeps the `enforce` default.

## Run it in your account

```bash
export AWS_PROFILE=<your profile>   # or AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY / AWS_SESSION_TOKEN
export AWS_REGION=<region>
make integration-smoke              # terraform init -test-directory=tests/integration && terraform test -test-directory=tests/integration -filter=tests/integration/smoke.tftest.hcl
make integration-nat-egress
```

The credentials need the permissions in
[`iam/integration-permissions-policy.json`](iam/integration-permissions-policy.json)
(replace `<ACCOUNT_ID>`). The EC2 actions take no resource constraint; the
log-group, KMS-alias, and IAM-role actions are scoped to names starting with
`vpc-it-` and `vpc-nat-`, which is what the fixture produces. `kms:CreateKey`
takes no resource constraint either, so key management is scoped to the
account's keys.

`terraform test` runs `tests/` only by default, so these suites never run in
the credential-free quality pipeline. The fixture module is excluded from the
Checkov and Trivy scans (`.checkov.yml`, `trivy.yaml`) because it is
short-lived test infrastructure, not a deployable pattern.

## Run it from GitHub Actions (owner lane)

The `integration` workflow (`.github/workflows/integration.yml`) is dispatch-only
and assumes a role through GitHub OIDC. It reads everything account-specific
from the protected `integration` environment of the repository, so the code
stays universal:

| Environment variable | Meaning |
| --- | --- |
| `AWS_INTEGRATION_ROLE_ARN` | Role the workflow assumes. Trust policy: [`iam/github-oidc-trust-policy.json`](iam/github-oidc-trust-policy.json) with `<OWNER>/<REPO>` set to this repository; permissions: the policy above. |
| `AWS_INTEGRATION_REGION` | Region for the VPC under test. |

Dispatch with `gh workflow run integration.yml -f suite=smoke` (or
`nat-egress`). Protect the environment with required reviewers so a run cannot
be started from a pull request by anyone with write access.

For this repository's owner the environment is prepared with the sandbox
region; the role ARN is added once the role exists in the sandbox account,
created through the platform's delivery IAM module with the trust policy above
and the subject `repo:hatan4ik/aws.modules.vpc:environment:integration`.
