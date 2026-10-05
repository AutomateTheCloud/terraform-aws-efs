# Copyright 2025 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

# Test fixture: the network is created in the same run as the file system, so the
# VPC, subnet and security group IDs are not known until apply.
terraform {
  required_version = ">= 1.9"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
  }
}

resource "aws_vpc" "this" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "a" {
  vpc_id     = aws_vpc.this.id
  cidr_block = "10.0.1.0/24"
}

resource "aws_security_group" "clients" {
  name        = "clients"
  description = "Clients of the file system"
  vpc_id      = aws_vpc.this.id
}

module "efs" {
  source = "../../.."

  details       = { scope = "Test", purpose = "Same Run", environment = "test" }
  vpc_id        = aws_vpc.this.id
  mount_targets = { a = { subnet_id = aws_subnet.a.id } }
  security_group_ingress = {
    vpc     = { cidr_ipv4 = aws_vpc.this.cidr_block }
    clients = { security_group_id = aws_security_group.clients.id }
  }
}
