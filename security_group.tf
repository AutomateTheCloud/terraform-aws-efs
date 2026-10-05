# Copyright 2025 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

# The security group of the mount targets. It allows NFS from the sources in
# security_group_ingress and nothing else. It has no egress rules: EFS only answers
# connections, and security groups let replies out on their own.
resource "aws_security_group" "this" {
  region                 = var.region
  name_prefix            = "${local.name}-"
  description            = "${local.scope.name} - ${local.purpose.name} [${local.environment.name}] (${local.aws.region.name}): EFS mount targets"
  vpc_id                 = var.vpc_id
  revoke_rules_on_delete = true

  tags = merge(local.tags, { Name = local.name })

  # A new name or description replaces the group. Creating the new group first lets
  # the mount targets move to it before the old one, which they still use, is deleted.
  lifecycle {
    create_before_destroy = true
  }
}
