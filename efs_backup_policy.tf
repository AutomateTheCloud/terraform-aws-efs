# Copyright 2026 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

resource "aws_efs_backup_policy" "this" {
  region         = var.region
  file_system_id = aws_efs_file_system.this.id

  backup_policy {
    status = var.automatic_backups ? "ENABLED" : "DISABLED"
  }
}
