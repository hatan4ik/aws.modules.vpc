mock_provider "aws" {}

variables {
  delegated_admin_account_id = "111122223333"
}

run "plans_organization_ipam_delegation" {
  command = plan

  assert {
    condition     = aws_vpc_ipam_organization_admin_account.this.delegated_admin_account_id == "111122223333"
    error_message = "The Organizations root must delegate IPAM administration to the approved Network account."
  }
}

run "rejects_invalid_delegated_account" {
  command = plan

  variables {
    delegated_admin_account_id = "not-an-account"
  }

  expect_failures = [var.delegated_admin_account_id]
}
