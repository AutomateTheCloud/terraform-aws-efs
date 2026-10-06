# Copyright 2026 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

output "metadata" {
  description = <<-EOT
    Everything the module created, in one object, so that other configurations need only one reference:

    - `details` - The scope, purpose and environment, each with its `name`, `abbr` (lowercase, words joined by underscores) and `machine` (lowercase letters and numbers only) forms, and the `tags` applied to every resource.
    - `aws` - The `account.id`, and the `region` `name`, `abbr` (such as `use1` for `us-east-1`) and `description`.
    - `efs_file_system` - The file system's `id`, `arn`, `dns_name` (the name clients mount), `encrypted`, `kms_key_id`, `performance_mode`, `throughput_mode`, `lifecycle_policy`, `size_in_bytes`, `tags` and the rest of its attributes.
    - `efs_mount_target` - The mount targets, keyed like `mount_targets`, each with its `id`, `subnet_id`, `ip_address`, `availability_zone_name`, `mount_target_dns_name` and `network_interface_id`.
    - `security_group` - The mount targets' security group, with its `id`, `arn` and `name`.
    - `vpc_security_group_ingress_rule` - The ingress rules, keyed like `security_group_ingress`, or `null` when there are none.
    - `efs_backup_policy` - The backup setting, with `backup_policy[0].status`.
    - `efs_file_system_policy` - The file system policy, with its `policy` JSON, or `null` when no policy is created.
  EOT
  value = {
    details = {
      scope = {
        name    = local.scope.name
        abbr    = local.scope.abbr
        machine = local.scope.machine
      }
      purpose = {
        name    = local.purpose.name
        abbr    = local.purpose.abbr
        machine = local.purpose.machine
      }
      environment = {
        name    = local.environment.name
        abbr    = local.environment.abbr
        machine = local.environment.machine
      }
      tags = local.tags
    }

    aws = {
      account = {
        id = local.aws.account.id
      }
      region = {
        name        = local.aws.region.name
        abbr        = local.aws.region.abbr
        description = local.aws.region.description
      }
    }

    # One entry per resource. Resources that are not created are null.
    efs_backup_policy               = local.output_resources.efs_backup_policy
    efs_file_system                 = local.output_resources.efs_file_system
    efs_file_system_policy          = local.output_resources.efs_file_system_policy
    efs_mount_target                = local.output_resources.efs_mount_target
    security_group                  = local.output_resources.security_group
    vpc_security_group_ingress_rule = local.output_resources.vpc_security_group_ingress_rule
  }
}

locals {
  # Each resource's attributes are listed one by one. Referencing a whole resource, or
  # iterating over it, would also reference its deprecated attributes, and every
  # caller's plan would print deprecation warnings.
  output_resources = {
    efs_file_system = {
      arn                             = aws_efs_file_system.this.arn
      availability_zone_id            = aws_efs_file_system.this.availability_zone_id
      availability_zone_name          = aws_efs_file_system.this.availability_zone_name
      creation_token                  = aws_efs_file_system.this.creation_token
      dns_name                        = aws_efs_file_system.this.dns_name
      encrypted                       = aws_efs_file_system.this.encrypted
      id                              = aws_efs_file_system.this.id
      kms_key_id                      = aws_efs_file_system.this.kms_key_id
      lifecycle_policy                = aws_efs_file_system.this.lifecycle_policy
      name                            = aws_efs_file_system.this.name
      number_of_mount_targets         = aws_efs_file_system.this.number_of_mount_targets
      owner_id                        = aws_efs_file_system.this.owner_id
      performance_mode                = aws_efs_file_system.this.performance_mode
      protection                      = aws_efs_file_system.this.protection
      provisioned_throughput_in_mibps = aws_efs_file_system.this.provisioned_throughput_in_mibps
      region                          = aws_efs_file_system.this.region
      size_in_bytes                   = aws_efs_file_system.this.size_in_bytes
      tags                            = aws_efs_file_system.this.tags
      tags_all                        = aws_efs_file_system.this.tags_all
      throughput_mode                 = aws_efs_file_system.this.throughput_mode
    }

    efs_backup_policy = {
      backup_policy  = aws_efs_backup_policy.this.backup_policy
      file_system_id = aws_efs_backup_policy.this.file_system_id
      id             = aws_efs_backup_policy.this.id
      region         = aws_efs_backup_policy.this.region
    }

    efs_file_system_policy = length(aws_efs_file_system_policy.this) == 0 ? null : {
      bypass_policy_lockout_safety_check = aws_efs_file_system_policy.this[0].bypass_policy_lockout_safety_check
      file_system_id                     = aws_efs_file_system_policy.this[0].file_system_id
      id                                 = aws_efs_file_system_policy.this[0].id
      policy                             = aws_efs_file_system_policy.this[0].policy
      region                             = aws_efs_file_system_policy.this[0].region
    }

    # Left out: ingress and egress, the group's inline rules. They are read when the
    # group is created, before the module's rules are attached, so they would change
    # on every caller's next plan. The rules are in vpc_security_group_*_rule instead.
    security_group = {
      arn                    = aws_security_group.this.arn
      description            = aws_security_group.this.description
      id                     = aws_security_group.this.id
      name                   = aws_security_group.this.name
      name_prefix            = aws_security_group.this.name_prefix
      owner_id               = aws_security_group.this.owner_id
      region                 = aws_security_group.this.region
      revoke_rules_on_delete = aws_security_group.this.revoke_rules_on_delete
      tags                   = aws_security_group.this.tags
      tags_all               = aws_security_group.this.tags_all
      vpc_id                 = aws_security_group.this.vpc_id
    }

    # Keyed like var.mount_targets. Left out: ip_address_type and ipv6_address, which
    # are newer than the provider floor.
    efs_mount_target = {
      for k in keys(var.mount_targets) : k => {
        availability_zone_id   = aws_efs_mount_target.this[k].availability_zone_id
        availability_zone_name = aws_efs_mount_target.this[k].availability_zone_name
        dns_name               = aws_efs_mount_target.this[k].dns_name
        file_system_arn        = aws_efs_mount_target.this[k].file_system_arn
        file_system_id         = aws_efs_mount_target.this[k].file_system_id
        id                     = aws_efs_mount_target.this[k].id
        ip_address             = aws_efs_mount_target.this[k].ip_address
        mount_target_dns_name  = aws_efs_mount_target.this[k].mount_target_dns_name
        network_interface_id   = aws_efs_mount_target.this[k].network_interface_id
        owner_id               = aws_efs_mount_target.this[k].owner_id
        region                 = aws_efs_mount_target.this[k].region
        security_groups        = aws_efs_mount_target.this[k].security_groups
        subnet_id              = aws_efs_mount_target.this[k].subnet_id
      }
    }

    # Keyed like var.security_group_ingress.
    vpc_security_group_ingress_rule = length(var.security_group_ingress) == 0 ? null : {
      for k in keys(var.security_group_ingress) : k => {
        arn                          = aws_vpc_security_group_ingress_rule.this[k].arn
        cidr_ipv4                    = aws_vpc_security_group_ingress_rule.this[k].cidr_ipv4
        cidr_ipv6                    = aws_vpc_security_group_ingress_rule.this[k].cidr_ipv6
        description                  = aws_vpc_security_group_ingress_rule.this[k].description
        from_port                    = aws_vpc_security_group_ingress_rule.this[k].from_port
        id                           = aws_vpc_security_group_ingress_rule.this[k].id
        ip_protocol                  = aws_vpc_security_group_ingress_rule.this[k].ip_protocol
        prefix_list_id               = aws_vpc_security_group_ingress_rule.this[k].prefix_list_id
        referenced_security_group_id = aws_vpc_security_group_ingress_rule.this[k].referenced_security_group_id
        region                       = aws_vpc_security_group_ingress_rule.this[k].region
        security_group_id            = aws_vpc_security_group_ingress_rule.this[k].security_group_id
        security_group_rule_id       = aws_vpc_security_group_ingress_rule.this[k].security_group_rule_id
        tags                         = aws_vpc_security_group_ingress_rule.this[k].tags
        tags_all                     = aws_vpc_security_group_ingress_rule.this[k].tags_all
        to_port                      = aws_vpc_security_group_ingress_rule.this[k].to_port
      }
    }
  }
}
