# Copyright 2025 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

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
  details       = { scope = "Test", purpose = "Region", environment = "test" }
  vpc_id        = "vpc-0123456789abcdef0"
  mount_targets = { a = { subnet_id = "subnet-0000000000000000a" } }
}

run "provider_region_by_default" {
  command = plan
  assert {
    condition     = output.metadata.aws.region.name == "us-east-1"
    error_message = "Expected the provider's Region."
  }
}

run "region_reaches_every_resource" {
  command = apply
  variables {
    region                 = "us-west-2"
    automatic_backups      = true
    security_group_ingress = { vpc = { cidr_ipv4 = "10.0.0.0/16" } }
  }
  assert {
    condition = alltrue([
      aws_efs_backup_policy.this.region == "us-west-2",
      aws_efs_file_system.this.region == "us-west-2",
      aws_efs_file_system_policy.this[0].region == "us-west-2",
      aws_efs_mount_target.this["a"].region == "us-west-2",
      aws_security_group.this.region == "us-west-2",
      aws_vpc_security_group_ingress_rule.this["vpc"].region == "us-west-2",
      output.metadata.aws.region.name == "us-west-2",
    ])
    error_message = "region was not passed through to every resource."
  }
}

# Any Region plans, including ones added after this module was written.
run "region_not_in_old_tables" {
  command = plan
  variables { region = "ap-southeast-7" }
  assert {
    condition     = output.metadata.aws.region.abbr == "apse7" && aws_efs_file_system.this.tags["Name"] == "test-region-test-apse7-efs"
    error_message = "Unexpected abbreviation."
  }
}

run "region_abbreviation_mexico" {
  command = plan
  variables { region = "mx-central-1" }
  assert {
    condition     = output.metadata.aws.region.abbr == "mxc1"
    error_message = "Unexpected abbreviation."
  }
}

run "region_abbreviation_override" {
  command = plan
  variables { region = "us-gov-west-1" }
  assert {
    condition     = output.metadata.aws.region.abbr == "ugw1"
    error_message = "Unexpected abbreviation."
  }
}
