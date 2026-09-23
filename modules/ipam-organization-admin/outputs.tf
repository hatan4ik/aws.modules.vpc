output "delegated_admin" {
  description = "Delegated VPC IPAM administrator recorded by the AWS Organizations management account."
  value = {
    account_id = aws_vpc_ipam_organization_admin_account.this.delegated_admin_account_id
    arn        = aws_vpc_ipam_organization_admin_account.this.arn
  }
}
