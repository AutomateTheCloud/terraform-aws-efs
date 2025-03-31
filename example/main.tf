terraform {
  required_version = "~> 1.11.0"
}

##-----------------------------------------------------------------------------
# Providers
provider "aws" {
  alias  = "example"
  region = "us-east-1"
}

##-----------------------------------------------------------------------------
# Module: EFS
module "efs" {
  source    = "../"
  providers = { aws.this = aws.example }

  details = {
    scope               = "Demo"
    purpose             = "EFS"
    environment         = "prd"
    additional_tags = {
      "Project"         = "Project Name"
      "ProjectID"       = "123456789"
      "Contact"         = "David Singer - david.singer@example.com"
    }
  }

  vpc_id   = "vpc-06a00000000000000"

  performance_mode       = "generalPurpose"
  provisioned_throughput = null
  
  lifecycle_transition_to_ia = "AFTER_90_DAYS"
  
  encryption = {
    enabled = true
    # kms_key_id = "arn:aws:kms:us-east-1:012345678901:key/56a50a23-2fc2-4ed5-b884-287af36b7df5"
  }

  security_group_access = [
    "10.75.192.0/20",
    "10.76.192.0/20",
    "10.77.192.0/20"
  ]
  
  subnets = [
    "subnet-00000000000000001",
    "subnet-00000000000000002",
    "subnet-00000000000000003"
  ]
}

##-----------------------------------------------------------------------------
# Outputs
output "metadata" {
  description = "Metadata"
  value = module.efs.metadata
}
