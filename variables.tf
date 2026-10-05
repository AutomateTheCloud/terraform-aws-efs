# Copyright 2025 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

variable "automatic_backups" {
  description = <<-EOT
    Turn on automatic daily backups of the file system with AWS Backup, kept for 35 days in the backup vault `aws/efs/automatic-backup-vault`. AWS Backup bills for the backup storage, so this is off by default. It can be turned on or off at any time without replacing the file system.
  EOT
  type        = bool
  default     = false
  nullable    = false
}

variable "details" {
  description = <<-EOT
    Names and tags shared by every resource in the module. `scope`, `purpose` and `environment` become the `Scope`, `Purpose` and `Environment` tags, and are converted to abbreviations that other modules can use in resource names (see the `metadata` output). [The `details` input](https://github.com/AutomateTheCloud/terraform-aws-efs#the-details-input) explains why it is required.

    - `scope` - (Required) What the resource belongs to, such as an organization or project: `Automate the Cloud`.
    - `purpose` - (Required) What the resource is for: `Web Site`.
    - `environment` - (Required) The environment: `Production`.
    - `scope_abbr`, `purpose_abbr`, `environment_abbr` - (Optional) Abbreviations to use instead of the generated ones, which are lowercase with words joined by underscores (`Web Site` becomes `web_site`).
    - `additional_tags` - (Optional) More tags for every resource, such as `{ CostCenter = "1234" }`.
  EOT
  type = object({
    scope            = string
    scope_abbr       = optional(string)
    purpose          = string
    purpose_abbr     = optional(string)
    environment      = string
    environment_abbr = optional(string)
    additional_tags  = optional(map(string), {})
  })
  nullable = false

  validation {
    condition     = trimspace(var.details.scope) != ""
    error_message = "Scope not specified."
  }

  validation {
    condition     = trimspace(var.details.purpose) != ""
    error_message = "Purpose not specified."
  }

  validation {
    condition     = trimspace(var.details.environment) != ""
    error_message = "Environment not specified."
  }
}

variable "kms_key_id" {
  description = <<-EOT
    ARN of the AWS Key Management Service (KMS) key that encrypts the file system. The file system is always encrypted; without a key, EFS uses the AWS managed key `aws/elasticfilesystem`.

    Changing the key, including setting one later, replaces the file system and deletes its data, because EFS cannot change the key of an existing file system.
  EOT
  type        = string
  default     = null

  validation {
    condition     = var.kms_key_id == null || startswith(coalesce(var.kms_key_id, "-"), "arn:")
    error_message = "kms_key_id must be the ARN of a KMS key, such as arn:aws:kms:us-east-1:123456789012:key/<key id>."
  }
}

variable "lifecycle_policy" {
  description = <<-EOT
    When files move between storage classes. Files that are not read for a while can move to the cheaper Infrequent Access (IA) and Archive storage classes, which charge for each read. With the default, `{}`, every file stays in Standard storage.

    - `transition_to_ia` - (Optional) Move a file to Infrequent Access this long after it was last accessed: `AFTER_1_DAY`, `AFTER_7_DAYS`, `AFTER_14_DAYS`, `AFTER_30_DAYS`, `AFTER_60_DAYS`, `AFTER_90_DAYS`, `AFTER_180_DAYS`, `AFTER_270_DAYS` or `AFTER_365_DAYS`.
    - `transition_to_archive` - (Optional) Move a file to Archive this long after it was last accessed, with the same values. Archive needs `throughput.mode = "elastic"` and the `generalPurpose` performance mode.
    - `transition_to_primary_storage_class` - (Optional) Set to `AFTER_1_ACCESS` to move a file back to Standard the first time it is read.
  EOT
  type = object({
    transition_to_ia                    = optional(string)
    transition_to_archive               = optional(string)
    transition_to_primary_storage_class = optional(string)
  })
  default  = {}
  nullable = false

  validation {
    condition = alltrue([
      for v in [var.lifecycle_policy.transition_to_ia, var.lifecycle_policy.transition_to_archive] :
      v == null || contains(["AFTER_1_DAY", "AFTER_7_DAYS", "AFTER_14_DAYS", "AFTER_30_DAYS", "AFTER_60_DAYS", "AFTER_90_DAYS", "AFTER_180_DAYS", "AFTER_270_DAYS", "AFTER_365_DAYS"], coalesce(v, "-"))
    ])
    error_message = "lifecycle_policy.transition_to_ia and transition_to_archive must be one of AFTER_1_DAY, AFTER_7_DAYS, AFTER_14_DAYS, AFTER_30_DAYS, AFTER_60_DAYS, AFTER_90_DAYS, AFTER_180_DAYS, AFTER_270_DAYS or AFTER_365_DAYS."
  }

  validation {
    condition     = var.lifecycle_policy.transition_to_primary_storage_class == null || var.lifecycle_policy.transition_to_primary_storage_class == "AFTER_1_ACCESS"
    error_message = "lifecycle_policy.transition_to_primary_storage_class must be \"AFTER_1_ACCESS\"."
  }

  validation {
    condition     = var.lifecycle_policy.transition_to_archive == null || (var.throughput.mode == "elastic" && var.performance_mode == "generalPurpose")
    error_message = "lifecycle_policy.transition_to_archive needs throughput.mode = \"elastic\" and performance_mode = \"generalPurpose\"."
  }
}

variable "mount_targets" {
  description = <<-EOT
    Where clients can reach the file system: one mount target per Availability Zone, each in a subnet of `vpc_id`. The keys are names you choose, such as the Availability Zone (`a`, `b`); they only identify each mount target, so a subnet created in the same configuration can be used.

    Each mount target takes:

    - `subnet_id` - (Required) The subnet to create the mount target in. Each subnet must be in a different Availability Zone.
    - `ip_address` - (Optional) The IPv4 address to give the mount target, from the subnet's range. Without it, AWS picks one.

    Changing a mount target's subnet or address replaces that mount target, and clients that mounted through it lose their connection. Adding or removing an entry does not affect the others.
  EOT
  type = map(object({
    subnet_id  = string
    ip_address = optional(string)
  }))
  nullable = false

  validation {
    condition     = length(var.mount_targets) > 0
    error_message = "mount_targets needs at least one entry."
  }
}

variable "performance_mode" {
  description = <<-EOT
    The file system's performance mode: `generalPurpose`, the default and the right choice for almost every workload, or `maxIO`, for thousands of clients at once at the cost of higher latency. `maxIO` cannot be used with Elastic throughput.

    Changing it replaces the file system and deletes its data.
  EOT
  type        = string
  default     = "generalPurpose"
  nullable    = false

  validation {
    condition     = contains(["generalPurpose", "maxIO"], var.performance_mode)
    error_message = "performance_mode must be \"generalPurpose\" or \"maxIO\"."
  }

  validation {
    condition     = !(var.performance_mode == "maxIO" && var.throughput.mode == "elastic")
    error_message = "performance_mode = \"maxIO\" cannot be used with throughput.mode = \"elastic\"."
  }
}

variable "policy" {
  description = <<-EOT
    The file system policy, which controls what NFS clients may do. By default the module creates a policy that refuses connections not encrypted with Transport Layer Security (TLS), and otherwise allows what EFS allows with no policy: any client that can reach a mount target may mount, write, and act as root. Network access is still controlled by `security_group_ingress`.

    - `require_encrypted_transport` - (Optional) Refuse clients that connect without TLS. Defaults to `true`. Mount with the EFS mount helper's `tls` option (`mount -t efs -o tls`). Set it to `false` only for clients that cannot use TLS.
    - `source_policy_documents` - (Optional) Policy documents in JSON, such as from `data.aws_iam_policy_document`, whose statements are added to the policy. When you give any, the module no longer allows every client: only your statements grant access, so they must include an `Allow` for each client that needs one. The [complete example](https://github.com/AutomateTheCloud/terraform-aws-efs/tree/main/examples/complete) grants one IAM role read and write access.

    With `require_encrypted_transport = false` and no documents, no policy is created.
  EOT
  type = object({
    require_encrypted_transport = optional(bool, true)
    source_policy_documents     = optional(list(string), [])
  })
  default  = {}
  nullable = false

  validation {
    condition     = alltrue([for d in var.policy.source_policy_documents : can(jsondecode(d).Statement[0])])
    error_message = "Each entry in policy.source_policy_documents must be a JSON policy document with a Statement list."
  }
}

variable "region" {
  description = <<-EOT
    The AWS Region to create the file system and everything else in, such as `us-west-2`. Defaults to the Region of the AWS provider passed to the module.
  EOT
  type        = string
  default     = null
}

variable "security_group_ingress" {
  description = <<-EOT
    Who can reach the file system over the network. The module creates a security group for the mount targets that allows NFS (TCP port 2049) from each source listed here, and from nothing else. With the default, `{}`, no client can connect. The keys are names you choose; they only identify each rule, so a security group created in the same configuration can be used.

    Each source takes exactly one of:

    - `cidr_ipv4` - An IPv4 range, such as `10.0.0.0/16`.
    - `cidr_ipv6` - An IPv6 range, such as `2001:db8::/56`.
    - `security_group_id` - A security group whose members may connect, such as the group of your instances.
    - `prefix_list_id` - A managed prefix list of ranges.

    and optionally:

    - `description` - (Optional) What the source is. Defaults to the key.
  EOT
  type = map(object({
    cidr_ipv4         = optional(string)
    cidr_ipv6         = optional(string)
    security_group_id = optional(string)
    prefix_list_id    = optional(string)
    description       = optional(string)
  }))
  default  = {}
  nullable = false

  validation {
    condition = alltrue([
      for s in values(var.security_group_ingress) :
      length([for v in [s.cidr_ipv4, s.cidr_ipv6, s.security_group_id, s.prefix_list_id] : v if v != null]) == 1
    ])
    error_message = "Each security_group_ingress entry needs exactly one of cidr_ipv4, cidr_ipv6, security_group_id or prefix_list_id."
  }

  validation {
    condition = alltrue([
      for s in values(var.security_group_ingress) :
      (s.cidr_ipv4 == null || can(cidrnetmask(s.cidr_ipv4))) && (s.cidr_ipv6 == null || (can(cidrhost(s.cidr_ipv6, 0)) && strcontains(coalesce(s.cidr_ipv6, "-"), ":")))
    ])
    error_message = "security_group_ingress: cidr_ipv4 must be an IPv4 range such as 10.0.0.0/16, and cidr_ipv6 an IPv6 range such as 2001:db8::/56."
  }
}

variable "throughput" {
  description = <<-EOT
    How the file system's throughput is set and billed.

    - `mode` - (Optional) `bursting`, the default: throughput grows with the amount of data stored, with credits for bursts. `elastic`: throughput scales with the workload, billed for each GB read and written; AWS recommends it for spiky or unpredictable workloads. `provisioned`: a fixed throughput you pay for whether it is used or not.
    - `provisioned_mibps` - (Optional) The throughput in MiB per second. Required with `provisioned`, and not allowed otherwise.

    The mode can be changed without replacing the file system. AWS allows a change of mode, or a decrease in `provisioned_mibps`, only once every 24 hours.
  EOT
  type = object({
    mode              = optional(string, "bursting")
    provisioned_mibps = optional(number)
  })
  default  = {}
  nullable = false

  validation {
    condition     = contains(["bursting", "elastic", "provisioned"], var.throughput.mode)
    error_message = "throughput.mode must be \"bursting\", \"elastic\" or \"provisioned\"."
  }

  validation {
    condition     = (var.throughput.mode == "provisioned") == (var.throughput.provisioned_mibps != null)
    error_message = "throughput.provisioned_mibps is required with throughput.mode = \"provisioned\", and not allowed with any other mode."
  }

  validation {
    condition     = var.throughput.provisioned_mibps == null || coalesce(var.throughput.provisioned_mibps, 0) >= 1
    error_message = "throughput.provisioned_mibps must be at least 1."
  }
}

variable "vpc_id" {
  description = <<-EOT
    The ID of the VPC the mount targets are in, such as `vpc-0123456789abcdef0`. The module creates the mount targets' security group in it.
  EOT
  type        = string
  nullable    = false

  validation {
    condition     = startswith(var.vpc_id, "vpc-")
    error_message = "vpc_id must be a VPC ID, such as vpc-0123456789abcdef0."
  }
}
