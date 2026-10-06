# Copyright 2026 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

# Same-run network: a VPC, subnet and client security group created in the same
# configuration as the file system, so their IDs are unknown at plan time.
run "same_run_network_plans" {
  command = plan
  module {
    source = "./tests/fixtures/same_run_network"
  }
}

run "same_run_network_applies" {
  command = apply
  module {
    source = "./tests/fixtures/same_run_network"
  }
  assert {
    condition     = length(module.efs.metadata.vpc_security_group_ingress_rule) == 2 && length(module.efs.metadata.efs_mount_target) == 1
    error_message = "Expected two rules and one mount target."
  }
}

mock_provider "aws" {
  mock_data "aws_region" {
    defaults = { region = "us-east-1", description = "US East (N. Virginia)" }
  }
  mock_data "aws_caller_identity" {
    defaults = { account_id = "111111111111" }
  }
  mock_resource "aws_vpc" {
    defaults = { id = "vpc-0123456789abcdef0" }
  }
  mock_resource "aws_efs_file_system" {
    defaults = { arn = "arn:aws:elasticfilesystem:us-east-1:111111111111:file-system/fs-0123456789abcdef0", id = "fs-0123456789abcdef0" }
  }
}
