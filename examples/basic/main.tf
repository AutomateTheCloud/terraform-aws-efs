# Copyright 2026 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

# An encrypted file system with a mount target in each subnet you give, reachable
# over NFS from anywhere in the VPC, and with clients required to use TLS.

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

data "aws_vpc" "this" {
  id = var.vpc_id
}

module "efs" {
  source = "../../"

  details = {
    scope       = "Example"
    purpose     = "Shared Files"
    environment = "Development"
  }

  vpc_id        = var.vpc_id
  mount_targets = { for id in var.subnet_ids : id => { subnet_id = id } }

  security_group_ingress = {
    vpc = { cidr_ipv4 = data.aws_vpc.this.cidr_block, description = "Anything in the VPC" }
  }
}

output "file_system" {
  description = "ID and DNS name of the file system"
  value = {
    id       = module.efs.metadata.efs_file_system.id
    dns_name = module.efs.metadata.efs_file_system.dns_name
  }
}
