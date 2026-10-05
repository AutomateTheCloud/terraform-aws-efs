# Copyright 2025 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

# Regression tests for the bugs fixed when the module was rewritten as 1.0.0.
mock_provider "aws" {
  mock_data "aws_region" {
    defaults = { region = "us-east-1", description = "US East (N. Virginia)" }
  }
  mock_data "aws_caller_identity" {
    defaults = { account_id = "111111111111" }
  }
  mock_resource "aws_efs_file_system" {
    defaults = { arn = "arn:aws:elasticfilesystem:us-east-1:111111111111:file-system/fs-0123456789abcdef0", id = "fs-0123456789abcdef0" }
  }
}

variables {
  details       = { scope = "Test", purpose = "Regression", environment = "test" }
  vpc_id        = "vpc-0123456789abcdef0"
  mount_targets = { a = { subnet_id = "subnet-0000000000000000a" } }
}

# An IPv6 range was taken for a security group ID.
run "ipv6_range_is_a_range" {
  command = plan
  variables { security_group_ingress = { v6 = { cidr_ipv6 = "2001:db8::/56" } } }
  assert {
    condition     = aws_vpc_security_group_ingress_rule.this["v6"].cidr_ipv6 == "2001:db8::/56" && aws_vpc_security_group_ingress_rule.this["v6"].referenced_security_group_id == null
    error_message = "An IPv6 range must be passed as cidr_ipv6."
  }
}

# Encryption could be turned off; it is now always on.
run "encryption_always_on" {
  command = plan
  assert {
    condition     = aws_efs_file_system.this.encrypted == true
    error_message = "The file system must always be encrypted."
  }
}

# The security group had an NFS egress rule to every client. It now has none.
run "no_egress_rules" {
  command = apply
  variables { security_group_ingress = { vpc = { cidr_ipv4 = "10.0.0.0/16" } } }
  assert {
    condition     = length(aws_security_group.this.egress) == 0
    error_message = "The security group must have no egress rules."
  }
}

# Removing one mount target moved the others to new indexes, which replaced them.
# Mount targets are now keyed by name.
run "mount_targets_before" {
  command = apply
  variables {
    mount_targets = {
      a = { subnet_id = "subnet-0000000000000000a" }
      b = { subnet_id = "subnet-0000000000000000b" }
    }
  }
}

run "mount_targets_after_removing_one" {
  command = plan
  variables {
    mount_targets = { b = { subnet_id = "subnet-0000000000000000b" } }
  }
  assert {
    condition     = keys(aws_efs_mount_target.this) == ["b"] && aws_efs_mount_target.this["b"].subnet_id == "subnet-0000000000000000b" && aws_efs_mount_target.this["b"].id == run.mount_targets_before.metadata.efs_mount_target["b"].id
    error_message = "The remaining mount target must be kept as it was."
  }
}

# Two module calls with the same details made security groups with the same name.
# The group now gets a unique name from a prefix.
run "security_group_name_is_a_prefix" {
  command = plan
  assert {
    condition     = aws_security_group.this.name_prefix == "test-regression-test-use1-efs-"
    error_message = "The security group must be named from a prefix."
  }
}
