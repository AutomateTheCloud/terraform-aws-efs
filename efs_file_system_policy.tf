# Copyright 2026 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

resource "aws_efs_file_system_policy" "this" {
  count = local.create_efs_file_system_policy ? 1 : 0

  region         = var.region
  file_system_id = aws_efs_file_system.this.id
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = local.efs_file_system_policy_statements
  })
}
