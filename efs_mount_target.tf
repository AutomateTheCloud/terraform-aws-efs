# Copyright 2026 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

resource "aws_efs_mount_target" "this" {
  for_each = var.mount_targets

  region          = var.region
  file_system_id  = aws_efs_file_system.this.id
  subnet_id       = each.value.subnet_id
  ip_address      = each.value.ip_address
  security_groups = [aws_security_group.this.id]
}
