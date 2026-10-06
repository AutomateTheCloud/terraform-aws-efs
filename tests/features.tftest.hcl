# Copyright 2026 Automate the Cloud Inc.
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
  details       = { scope = "Test", purpose = "Shared Files", environment = "test" }
  vpc_id        = "vpc-0123456789abcdef0"
  mount_targets = { a = { subnet_id = "subnet-0000000000000000a" }, b = { subnet_id = "subnet-0000000000000000b" } }
}

run "every_source_type" {
  command = plan
  variables {
    security_group_ingress = {
      vpc     = { cidr_ipv4 = "10.0.0.0/16", description = "The VPC" }
      vpc_v6  = { cidr_ipv6 = "2001:db8::/56" }
      clients = { security_group_id = "sg-0123456789abcdef0" }
      office  = { prefix_list_id = "pl-0123456789abcdef0" }
    }
  }
  assert {
    condition = alltrue([
      aws_vpc_security_group_ingress_rule.this["vpc"].cidr_ipv4 == "10.0.0.0/16",
      aws_vpc_security_group_ingress_rule.this["vpc"].description == "The VPC",
      aws_vpc_security_group_ingress_rule.this["vpc_v6"].cidr_ipv6 == "2001:db8::/56",
      aws_vpc_security_group_ingress_rule.this["vpc_v6"].description == "vpc_v6",
      aws_vpc_security_group_ingress_rule.this["clients"].referenced_security_group_id == "sg-0123456789abcdef0",
      aws_vpc_security_group_ingress_rule.this["office"].prefix_list_id == "pl-0123456789abcdef0",
    ])
    error_message = "Each source must reach its own attribute."
  }
  assert {
    condition = alltrue([for r in values(aws_vpc_security_group_ingress_rule.this) :
    r.ip_protocol == "tcp" && r.from_port == 2049 && r.to_port == 2049])
    error_message = "Rules must allow NFS only."
  }
}

run "throughput_elastic_and_archive" {
  command = plan
  variables {
    throughput       = { mode = "elastic" }
    lifecycle_policy = { transition_to_ia = "AFTER_30_DAYS", transition_to_archive = "AFTER_90_DAYS", transition_to_primary_storage_class = "AFTER_1_ACCESS" }
  }
  assert {
    condition = aws_efs_file_system.this.throughput_mode == "elastic" && aws_efs_file_system.this.provisioned_throughput_in_mibps == null && aws_efs_file_system.this.lifecycle_policy == tolist([
      { transition_to_ia = "AFTER_30_DAYS", transition_to_archive = null, transition_to_primary_storage_class = null },
      { transition_to_ia = null, transition_to_archive = null, transition_to_primary_storage_class = "AFTER_1_ACCESS" },
      { transition_to_ia = null, transition_to_archive = "AFTER_90_DAYS", transition_to_primary_storage_class = null },
    ])
    error_message = "Unexpected throughput or lifecycle settings."
  }
}

run "throughput_provisioned" {
  command = plan
  variables { throughput = { mode = "provisioned", provisioned_mibps = 128 } }
  assert {
    condition     = aws_efs_file_system.this.throughput_mode == "provisioned" && aws_efs_file_system.this.provisioned_throughput_in_mibps == 128
    error_message = "Unexpected throughput settings."
  }
}

run "customer_managed_key" {
  command = plan
  variables { kms_key_id = "arn:aws:kms:us-east-1:111111111111:key/1234abcd-12ab-34cd-56ef-1234567890ab" }
  assert {
    condition     = aws_efs_file_system.this.encrypted && aws_efs_file_system.this.kms_key_id == "arn:aws:kms:us-east-1:111111111111:key/1234abcd-12ab-34cd-56ef-1234567890ab"
    error_message = "The key must be used."
  }
}

run "automatic_backups" {
  command = plan
  variables { automatic_backups = true }
  assert {
    condition     = aws_efs_backup_policy.this.backup_policy[0].status == "ENABLED"
    error_message = "Backups must be on."
  }
}

run "mount_target_ip_address" {
  command = plan
  variables { mount_targets = { a = { subnet_id = "subnet-0000000000000000a", ip_address = "10.0.1.10" } } }
  assert {
    condition     = aws_efs_mount_target.this["a"].ip_address == "10.0.1.10" && length(aws_efs_mount_target.this) == 1
    error_message = "The address must be used."
  }
}

# The caller's statements replace the module's allow-all statement; the TLS statement stays.
run "source_policy_documents" {
  command = apply
  variables {
    policy = {
      source_policy_documents = [jsonencode({
        Version = "2012-10-17"
        Statement = [{
          Sid       = "AppReadWrite"
          Effect    = "Allow"
          Principal = { AWS = "arn:aws:iam::111111111111:role/app" }
          Action    = ["elasticfilesystem:ClientMount", "elasticfilesystem:ClientWrite"]
          Resource  = "*"
        }]
      })]
    }
  }
  assert {
    condition     = [for s in jsondecode(aws_efs_file_system_policy.this[0].policy).Statement : s.Sid] == ["RequireEncryptedTransport", "AppReadWrite"]
    error_message = "Unexpected policy statements."
  }
}

run "no_policy_when_nothing_asked" {
  command = plan
  variables { policy = { require_encrypted_transport = false } }
  assert {
    condition     = length(aws_efs_file_system_policy.this) == 0 && output.metadata.efs_file_system_policy == null
    error_message = "No policy expected."
  }
}

run "only_caller_statements_without_tls" {
  command = apply
  variables {
    policy = {
      require_encrypted_transport = false
      source_policy_documents     = [jsonencode({ Version = "2012-10-17", Statement = [{ Sid = "Mine", Effect = "Allow", Principal = { AWS = "*" }, Action = "elasticfilesystem:ClientMount", Resource = "*" }] })]
    }
  }
  assert {
    condition     = [for s in jsondecode(aws_efs_file_system_policy.this[0].policy).Statement : s.Sid] == ["Mine"]
    error_message = "Only the caller's statement expected."
  }
}
