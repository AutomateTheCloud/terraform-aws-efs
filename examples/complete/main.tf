# Copyright 2026 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

# Most of the module's options together: a customer managed KMS key, Elastic
# throughput, lifecycle transitions to Infrequent Access and Archive, automatic
# backups, network access from one security group only, and a file system policy
# that lets one IAM role mount and write.

terraform {
  required_version = ">= 1.9"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

variable "vpc_id" {
  description = "ID of the VPC to create the file system in"
  type        = string
}

variable "subnet_ids" {
  description = "IDs of the subnets for the mount targets, one in each Availability Zone"
  type        = list(string)
}

locals {
  details = {
    scope           = "Example"
    purpose         = "Application Data"
    environment     = "Development"
    additional_tags = { CostCenter = "1234" }
  }
}

# The key that encrypts the file system. Its policy is the default one: the account
# controls it through IAM.
resource "aws_kms_key" "efs" {
  description             = "Encrypts the example EFS file system"
  enable_key_rotation     = true
  deletion_window_in_days = 7
}

# The security group of the application's instances. Only its members can reach the
# file system over the network.
resource "aws_security_group" "app" {
  name_prefix = "example-app-"
  description = "Example application instances that use EFS"
  vpc_id      = var.vpc_id
}

resource "aws_vpc_security_group_egress_rule" "app_to_efs" {
  security_group_id            = aws_security_group.app.id
  description                  = "NFS to the file system"
  ip_protocol                  = "tcp"
  from_port                    = 2049
  to_port                      = 2049
  referenced_security_group_id = module.efs.metadata.security_group.id
}

# The role the application's instances use. The file system policy below lets it
# mount and write, through a mount target, and nothing else may.
resource "aws_iam_role" "app" {
  name_prefix = "example-efs-app-"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

data "aws_iam_policy_document" "app_access" {
  statement {
    sid     = "AppReadWrite"
    effect  = "Allow"
    actions = ["elasticfilesystem:ClientMount", "elasticfilesystem:ClientWrite"]
    # "*" means this file system: a file system policy applies only to its own file system.
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.app.arn]
    }

    condition {
      test     = "Bool"
      variable = "elasticfilesystem:AccessedViaMountTarget"
      values   = ["true"]
    }
  }
}

module "efs" {
  source = "../../"

  details = local.details

  vpc_id        = var.vpc_id
  mount_targets = { for id in var.subnet_ids : id => { subnet_id = id } }

  security_group_ingress = {
    app = { security_group_id = aws_security_group.app.id, description = "Application instances" }
  }

  kms_key_id        = aws_kms_key.efs.arn
  throughput        = { mode = "elastic" }
  automatic_backups = true

  lifecycle_policy = {
    transition_to_ia                    = "AFTER_30_DAYS"
    transition_to_archive               = "AFTER_90_DAYS"
    transition_to_primary_storage_class = "AFTER_1_ACCESS"
  }

  policy = {
    require_encrypted_transport = true
    source_policy_documents     = [data.aws_iam_policy_document.app_access.json]
  }
}

output "file_system" {
  description = "The file system, and the security group and role the application uses with it"
  value = {
    id                    = module.efs.metadata.efs_file_system.id
    arn                   = module.efs.metadata.efs_file_system.arn
    dns_name              = module.efs.metadata.efs_file_system.dns_name
    app_security_group_id = aws_security_group.app.id
    app_role_arn          = aws_iam_role.app.arn
  }
}
