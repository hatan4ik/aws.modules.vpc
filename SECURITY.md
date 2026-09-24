# Security policy

## Supported versions

| Version | Supported |
| --- | --- |
| 1.x | Yes. Security fixes and functional fixes on the latest minor release. |
| 0.x | Security fixes only, until 2026-12-31. Upgrade with [docs/UPGRADE-1.0.md](docs/UPGRADE-1.0.md). |
| Unreleased `main` | Not supported for production use. |

## Reporting a vulnerability

Use GitHub private vulnerability reporting on this repository: open the Security tab and choose "Report a vulnerability". Do not open a public issue, pull request, or discussion for a security problem.

Include the module version or commit SHA, the inputs that reproduce the problem, the resulting plan or policy, and the impact you see. Redact account IDs, VPC and subnet IDs, and key ARNs.

## What counts

- A module default that weakens security: an internet gateway, NAT gateway, or public subnet created without being declared, a default route accepted without the tier's `allow_default_route`, a default security group left with rules, VPC Encryption Control not enforced, flow logs off or retained for less than a year without a warning, an endpoint security group admitting anything but HTTPS from the VPC CIDRs.
- A validation bypass: an input the module claims to reject at plan time but that reaches the provider, including a route with two targets, a NAT gateway in an undeclared subnet, or an endpoint in an undeclared tier.
- IAM or KMS over-permission: a flow-log delivery role granted an action or a log group the caller did not declare, a trust policy assumable by a principal other than `vpc-flow-logs.amazonaws.com`, or a created key policy admitting the CloudWatch Logs service for any log group other than this one.
- A caller-supplied KMS key, log group, security group, Elastic IP, or route table that the module modifies.
- A tag or name that drifts from the documented contract in a way that would make a platform root discover the wrong subnets.
- A dependency problem in the release pipeline that could publish unverified code.

Findings in your own inputs (for example a `0.0.0.0/0` route you declared with `allow_default_route = true`) or in AWS services themselves are out of scope here; report the latter to AWS.

## Response

We acknowledge a report within 5 business days and keep you informed while we confirm, fix, and release. A fix ships as a patch release of every supported line with a `CHANGELOG.md` entry that credits the reporter unless they ask otherwise. Please give us a reasonable window before disclosing publicly.

## Security design

The module is secure by default: no internet gateway, NAT gateway, or public subnet unless declared; the default security group always managed as deny-all; VPC Encryption Control enforced; flow logs on for all traffic at 60-second aggregation with one-year minimum retention and a delivery role scoped to one log group; a created flow-log key whose policy admits only the CloudWatch Logs service for that log group; an endpoint security group that admits HTTPS from the VPC only, with standalone rules; default routes rejected unless a tier opts in; every route naming exactly one destination and one target; partition, region, and account as inputs with a data-source fallback only where the key policy needs it; and only `Name` and `Tier` tags added. Every claim is enforced by a validation, a precondition, or a `check` block with a `terraform test` case behind it. The full description is in the [Security model](README.md#security-model) section of the README, and the reasoning in [docs/DESIGN.md](docs/DESIGN.md).
