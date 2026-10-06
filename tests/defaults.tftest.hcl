# Copyright 2026 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

# Offline tests: every provider is mocked, so no AWS account is used.
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
  details       = { scope = "Test", purpose = "Shared Files", environment = "test" }
  vpc_id        = "vpc-0123456789abcdef0"
  mount_targets = { a = { subnet_id = "subnet-0000000000000000a" }, b = { subnet_id = "subnet-0000000000000000b" } }
}

run "defaults_are_secure" {
  command = apply

  assert {
    condition     = aws_efs_file_system.this.encrypted == true
    error_message = "The file system must be encrypted."
  }
  assert {
    condition     = jsondecode(aws_efs_file_system_policy.this[0].policy).Statement[1] == { Sid = "RequireEncryptedTransport", Effect = "Deny", Principal = { AWS = "*" }, Action = "*", Resource = "arn:aws:elasticfilesystem:us-east-1:111111111111:file-system/fs-0123456789abcdef0", Condition = { Bool = { "aws:SecureTransport" = "false" } } }
    error_message = "Clients without TLS must be refused by default."
  }
  assert {
    condition     = length(jsondecode(aws_efs_file_system_policy.this[0].policy).Statement) == 2 && jsondecode(aws_efs_file_system_policy.this[0].policy).Statement[0].Condition == { Bool = { "elasticfilesystem:AccessedViaMountTarget" = "true" } }
    error_message = "The default policy must allow clients only through mount targets, plus the TLS statement."
  }
  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.this) == 0
    error_message = "No network access may be allowed by default."
  }
  assert {
    condition     = aws_efs_backup_policy.this.backup_policy[0].status == "DISABLED"
    error_message = "Automatic backups must be off by default."
  }
  assert {
    condition     = aws_efs_file_system.this.performance_mode == "generalPurpose" && aws_efs_file_system.this.throughput_mode == "bursting" && length(aws_efs_file_system.this.lifecycle_policy) == 0
    error_message = "Unexpected performance, throughput or lifecycle defaults."
  }
  assert {
    condition     = toset(keys(aws_efs_mount_target.this)) == toset(["a", "b"]) && aws_efs_mount_target.this["b"].subnet_id == "subnet-0000000000000000b"
    error_message = "One mount target per entry expected."
  }
  assert {
    condition     = aws_efs_file_system.this.tags == tomap({ Scope = "Test", Purpose = "Shared Files", Environment = "test", Name = "test-shared_files-test-use1-efs" })
    error_message = "Unexpected tags."
  }
  assert {
    condition     = startswith(aws_security_group.this.name_prefix, "test-shared_files-test-use1-efs-") && aws_security_group.this.vpc_id == "vpc-0123456789abcdef0"
    error_message = "Unexpected security group."
  }
  assert {
    condition     = output.metadata.vpc_security_group_ingress_rule == null && output.metadata.efs_file_system.id == "fs-0123456789abcdef0" && output.metadata.aws.region.abbr == "use1" && output.metadata.efs_mount_target["a"].subnet_id == "subnet-0000000000000000a"
    error_message = "Unexpected metadata output."
  }
}

run "abbreviation_override" {
  command = plan
  variables {
    details = { scope = "Test", purpose = "Shared Files", environment = "Production", environment_abbr = "prd", additional_tags = { CostCenter = "1234" } }
  }
  assert {
    condition     = output.metadata.details.environment.abbr == "prd" && output.metadata.details.purpose.machine == "sharedfiles" && aws_efs_file_system.this.tags["CostCenter"] == "1234"
    error_message = "Unexpected details handling."
  }
}

run "details_scope_required" {
  command = plan
  variables { details = { scope = " ", purpose = "p", environment = "e" } }
  expect_failures = [var.details]
}

run "details_purpose_required" {
  command = plan
  variables { details = { scope = "s", purpose = "", environment = "e" } }
  expect_failures = [var.details]
}

run "details_environment_required" {
  command = plan
  variables { details = { scope = "s", purpose = "p", environment = "" } }
  expect_failures = [var.details]
}

run "mount_targets_required" {
  command = plan
  variables { mount_targets = {} }
  expect_failures = [var.mount_targets]
}

run "vpc_id_validated" {
  command = plan
  variables { vpc_id = "subnet-0123456789abcdef0" }
  expect_failures = [var.vpc_id]
}

run "kms_key_id_must_be_arn" {
  command = plan
  variables { kms_key_id = "alias/my-key" }
  expect_failures = [var.kms_key_id]
}

run "performance_mode_validated" {
  command = plan
  variables { performance_mode = "fast" }
  expect_failures = [var.performance_mode]
}

run "max_io_not_with_elastic" {
  command = plan
  variables {
    performance_mode = "maxIO"
    throughput       = { mode = "elastic" }
  }
  expect_failures = [var.performance_mode]
}

run "throughput_mode_validated" {
  command = plan
  variables { throughput = { mode = "burst" } }
  expect_failures = [var.throughput]
}

run "provisioned_needs_mibps" {
  command = plan
  variables { throughput = { mode = "provisioned" } }
  expect_failures = [var.throughput]
}

run "mibps_only_with_provisioned" {
  command = plan
  variables { throughput = { mode = "elastic", provisioned_mibps = 100 } }
  expect_failures = [var.throughput]
}

run "mibps_at_least_one" {
  command = plan
  variables { throughput = { mode = "provisioned", provisioned_mibps = 0 } }
  expect_failures = [var.throughput]
}

run "lifecycle_values_validated" {
  command = plan
  variables { lifecycle_policy = { transition_to_ia = "AFTER_2_DAYS" } }
  expect_failures = [var.lifecycle_policy]
}

run "lifecycle_primary_validated" {
  command = plan
  variables { lifecycle_policy = { transition_to_primary_storage_class = "AFTER_2_ACCESSES" } }
  expect_failures = [var.lifecycle_policy]
}

run "archive_needs_elastic" {
  command = plan
  variables { lifecycle_policy = { transition_to_archive = "AFTER_90_DAYS" } }
  expect_failures = [var.lifecycle_policy]
}

run "ingress_needs_exactly_one_source" {
  command = plan
  variables { security_group_ingress = { both = { cidr_ipv4 = "10.0.0.0/16", security_group_id = "sg-0123456789abcdef0" } } }
  expect_failures = [var.security_group_ingress]
}

run "ingress_needs_a_source" {
  command = plan
  variables { security_group_ingress = { none = { description = "nothing" } } }
  expect_failures = [var.security_group_ingress]
}

run "ingress_ipv4_validated" {
  command = plan
  variables { security_group_ingress = { v6 = { cidr_ipv4 = "2001:db8::/56" } } }
  expect_failures = [var.security_group_ingress]
}

run "ingress_ipv6_validated" {
  command = plan
  variables { security_group_ingress = { v4 = { cidr_ipv6 = "10.0.0.0/16" } } }
  expect_failures = [var.security_group_ingress]
}

run "policy_documents_validated" {
  command = plan
  variables { policy = { source_policy_documents = ["{}"] } }
  expect_failures = [var.policy]
}
