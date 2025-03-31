# AWS - EFS - Terraform Module
Terraform module to create an EFS Filesystem (AutomateTheCloud model)

***

## Usage
```hcl
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
```

***

## Inputs
| Name | Description | Type | Default |
|------|-------------|:----:|:-------:|
| `encryption` | Encryption | `any` | |
| `lifecycle_transition_to_ia` | Lifecycle Policy: Transition files to IA Storage Class (`AFTER_7_DAYS`, `AFTER_14_DAYS`, `AFTER_30_DAYS`, `AFTER_60_DAYS`, `AFTER_90_DAYS`) | `string` | |
| `performance_mode` | EFS Performance Mode (generalPurpose, maxIO) | `string` | `generalPurpose` |
| `provisioned_throughput` | EFS Provisioned Throughput (in MiBPS) | `number` | `null` |
| `security_group_access` | Security Group Access sources | `list` | `[]` |
| `subnets` | Subnet IDs for Mount Targets | `list` | `[]` |
| `vpc_id` | VPC ID | `string` | |

## Inputs (Details)
| Name | Description | Type | Default |
|------|-------------|:----:|:-------:|
| `details.scope` | (Required) Scope Name - What does this object belong to? (Organization Name, Project, etc) | `string` | |
| `details.scope_abbr` | (Optional) Scope [Abbreviation](#Abbreviations) Override | `string` | |
| `details.purpose` | (Required) Purpose Name - What is the purpose or function of this object, or what does this object server? | `string` | |
| `details.purpose_abbr` | (Optional) Purpose [Abbreviation](#Abbreviations) Override | `string` | |
| `details.environment` | (Required) Environment Name | `string` | |
| `details.environment_abbr` | (Optional) Environment [Abbreviation](#Abbreviations) Override | `string` | |
| `details.additional_tags` | (Optional) [Additional Tags](#Additional-Tags) for resources | `map` | `[]` |

***

## Outputs
All outputs from this module are mapped to a single output named `metadata` to make it easier to capture all of the relevant metadata that would be useful when referenced by other stacks (requires only a single output reference in your code, instead of dozens!)

| Name | Description |
|:-----|:------------|
| `details.scope.name` | Scope name |
| `details.scope.abbr` | Scope abbreviation |
| `details.scope.machine` | Scope machine-friendly abbreviation |
| `details.purpose.name` | Purpose name |
| `details.purpose.abbr` | Purpose abbreviation |
| `details.purpose.machine` | Purpose machine-friendly abbreviation |
| `details.environment.name` | Environment name |
| `details.environment.abbr` | Environment abbreviation |
| `details.environment.machine` | Environment machine-friendly abbreviation |
| `details.tags` | Map of tags applied to all resources |
| `aws.account.id` | AWS Account ID |
| `aws.region.name` | AWS Region name, example: `us-east-1` |
| `aws.region.abbr` | AWS Region four letter abbreviation, example: `use1` |
| `aws.region.description` | AWS Region description, example: `US East (N. Virginia)` |
| `efs.filesystem.id` | EFS - Filesystem: ID |
| `efs.filesystem.arn` | EFS - Filesystem: ARN |
| `efs.filesystem.dns_name` | EFS - Filesystem: DNS Name |
| `efs.filesystem.kms_key_id` | EFS - Filesystem: KMS Key ID |
| `efs.mount_target` | EFS - Mount Targets |
| `kms.key.id` | KMS Key ID |
| `kms.key.arn` | KMS Key ARN |
| `kms.alias.name` | KMS Key Alias Name |
| `kms.alias.arn` | KMS Key Alias ARN |
| `security_group.id` | Security Group ID |
| `security_group.arn` | Security Group ARN |
| `security_group.name` | Security Group Name |

***

## Notes

### Abbreviations
* When generating resource names, the module converts each identifier to a more 'machine-friendly' abbreviated format, removing all special characters, replacing spaces with underscores (_), and converting to lowercase. Example: 'Demo - Module' => 'demo_module'
* Not all resource names allow underscores. When those are encountered, the detail identifier will have the underscore removed (test_example => testexample) automatically. This machine-friendly abbreviation is referred to as 'machine' within the module.
* The abbreviations can be overridden by suppling the abbreviated names (ie: scope_abbr). This is useful when you have a long name and need the created resource names to be shorter. Some resources in AWS have shorter name constraints than others, or you may just prefer it shorter. NOTE: If specifying the Abbreviation, be sure to follow the convention of no spaces and no special characters (except for underscore), otherwise resoure creation may fail.

### Additional Tags
* You can specify additional tags for resources by adding to the `details.additional_tags` map.
```
additional_tags = {
  "Example"         = "Extra Tag"
  "Project"         = "Project Name"
  "CostCenter"      = "123456"
}
```

***

## Terraform Versions
Terraform ~> 1.11.0 is supported.

## Provider Versions
| Name | Version |
|------|---------|
| aws | `~> 5.93` |
