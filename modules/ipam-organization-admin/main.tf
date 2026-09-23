# This module runs only in the AWS Organizations management account. It makes
# the Network account the IPAM delegated administrator and enables the RAM
# organization-sharing prerequisite before that account creates any pool share.
resource "aws_ram_sharing_with_organization" "this" {}

resource "aws_vpc_ipam_organization_admin_account" "this" {
  delegated_admin_account_id = var.delegated_admin_account_id

  depends_on = [aws_ram_sharing_with_organization.this]
}
