# Copyright 2026 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

locals {
  # The Name tag of the file system and its security group.
  name = "${local.scope.abbr}-${local.purpose.abbr}-${local.environment.abbr}-${local.aws.region.abbr}-efs"

  efs_file_system_arn = aws_efs_file_system.this.arn

  # Every statement the file system policy can contain, each switched on by an input.
  efs_file_system_policy_statements = concat(
    # Without a policy, EFS lets any client that reaches a mount target mount, write and
    # act as root. A policy replaces that default, so the module states it again, unless
    # the caller's own statements decide who has access.
    [for s in [{
      Sid       = "AllowClientsThroughMountTargets"
      Effect    = "Allow"
      Principal = { AWS = "*" }
      Action    = ["elasticfilesystem:ClientMount", "elasticfilesystem:ClientWrite", "elasticfilesystem:ClientRootAccess"]
      Resource  = local.efs_file_system_arn
      Condition = { Bool = { "elasticfilesystem:AccessedViaMountTarget" = "true" } }
    }] : s if length(var.policy.source_policy_documents) == 0],

    # Require Encrypted Transport
    [for s in [{
      Sid       = "RequireEncryptedTransport"
      Effect    = "Deny"
      Principal = { AWS = "*" }
      Action    = "*"
      Resource  = local.efs_file_system_arn
      Condition = { Bool = { "aws:SecureTransport" = "false" } }
    }] : s if var.policy.require_encrypted_transport],

    # Statements from the caller's own policy documents
    flatten([for doc in var.policy.source_policy_documents : jsondecode(doc).Statement]),
  )

  # Decided from the inputs alone, so the count is known at plan time.
  create_efs_file_system_policy = var.policy.require_encrypted_transport || length(var.policy.source_policy_documents) > 0
}
