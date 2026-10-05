# Copyright 2025 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

resource "aws_efs_file_system" "this" {
  region           = var.region
  encrypted        = true
  kms_key_id       = var.kms_key_id
  performance_mode = var.performance_mode

  throughput_mode                 = var.throughput.mode
  provisioned_throughput_in_mibps = var.throughput.provisioned_mibps

  # EFS takes each transition in a block of its own.
  dynamic "lifecycle_policy" {
    for_each = var.lifecycle_policy.transition_to_ia == null ? [] : [var.lifecycle_policy.transition_to_ia]
    content {
      transition_to_ia = lifecycle_policy.value
    }
  }

  dynamic "lifecycle_policy" {
    for_each = var.lifecycle_policy.transition_to_primary_storage_class == null ? [] : [var.lifecycle_policy.transition_to_primary_storage_class]
    content {
      transition_to_primary_storage_class = lifecycle_policy.value
    }
  }

  dynamic "lifecycle_policy" {
    for_each = var.lifecycle_policy.transition_to_archive == null ? [] : [var.lifecycle_policy.transition_to_archive]
    content {
      transition_to_archive = lifecycle_policy.value
    }
  }

  tags = merge(local.tags, { Name = local.name })
}
