# Terraform module for Amazon EFS file systems

Creates an Amazon Elastic File System (EFS) file system, a mount target in each subnet you give, and a security group that controls which clients can reach it. Optional settings cover throughput, lifecycle transitions to cheaper storage classes, automatic backups, and the file system policy.

The defaults are the settings most file systems should have. A file system created with only the required inputs is encrypted, refuses clients that do not use Transport Layer Security (TLS), and cannot be reached over the network until you allow a source.

## What it configures

| Setting | Default | Input |
|---|---|---|
| Encryption at rest | Always on, with the AWS managed key | `kms_key_id` |
| Encryption in transit (TLS) | Required | `policy.require_encrypted_transport` |
| Network access | None: no client can connect | `security_group_ingress` |
| Who may mount, write and act as root | Any client that reaches a mount target | `policy.source_policy_documents` |
| Mount targets | One per entry, required | `mount_targets` |
| Performance mode | General Purpose | `performance_mode` |
| Throughput mode | Bursting | `throughput` |
| Lifecycle transitions | None: files stay in Standard | `lifecycle_policy` |
| Automatic backups | Off | `automatic_backups` |

## Usage

```hcl
module "efs" {
  source  = "AutomateTheCloud/efs/aws"
  version = "~> 1.0"

  details = {
    scope       = "Automate the Cloud"
    purpose     = "Shared Files"
    environment = "Production"
  }

  vpc_id = "vpc-0123456789abcdef0"
  mount_targets = {
    a = { subnet_id = "subnet-0123456789abcdef0" }
    b = { subnet_id = "subnet-0fedcba9876543210" }
  }

  security_group_ingress = {
    app = { security_group_id = "sg-0123456789abcdef0", description = "Application instances" }
  }
}
```

`details`, `vpc_id` and `mount_targets` are the only required inputs. `details` sets the `Scope`, `Purpose` and `Environment` tags on every resource.

Clients mount with the [EFS mount helper](https://docs.aws.amazon.com/efs/latest/ug/efs-mount-helper.html) and its `tls` option: `sudo mount -t efs -o tls <file system id>:/ /mnt/efs`.

The module uses your default `aws` provider and creates everything in that provider's Region. To create the file system somewhere else without configuring another provider, set `region`:

```hcl
module "efs_us_west_2" {
  source  = "AutomateTheCloud/efs/aws"
  version = "~> 1.0"

  region        = "us-west-2"
  details       = { scope = "Automate the Cloud", purpose = "Shared Files", environment = "Production" }
  vpc_id        = "vpc-0abcdef0123456789"
  mount_targets = { a = { subnet_id = "subnet-0abcdef0123456789" } }
}
```

The VPC and subnets must be in that Region too.

To use a provider configured for another account, pass it explicitly with `providers = { aws = aws.other_account }`.

## The `details` input

Most modules ask only for what the resource itself needs. This one also requires `details`: three names that say what the file system belongs to, what it is for, and which environment it is in. Every Automate the Cloud module takes the same input, and requiring it is deliberate.

```hcl
details = {
  scope       = "Automate the Cloud" # what it belongs to: an organization, team or project
  purpose     = "Shared Files"       # what it is for
  environment = "Production"         # which environment
}
```

**Every resource can be traced.** The three names become the `Scope`, `Purpose` and `Environment` tags on every resource the module creates. Months later, anyone looking at a file system in the AWS console, or at a line on the bill, can see who it belongs to and why it exists. With cost allocation tags turned on in AWS Billing, the same tags split your bill by project and environment. Because the input is required and checked, no resource can be created without them.

**One definition for a whole stack.** Write `details` once and pass the same value to every module, so the file system, its bucket, its certificate and everything else are tagged alike. Tags you want everywhere, such as a cost center or the Terraform workspace, go in `additional_tags`:

```hcl
locals {
  details = {
    scope           = "Automate the Cloud"
    purpose         = "Shared Files"
    environment     = "Production"
    additional_tags = { CostCenter = "1234", IaC = "true" }
  }
}

module "shared_files" {
  source  = "AutomateTheCloud/efs/aws"
  version = "~> 1.0"

  details       = local.details
  vpc_id        = "vpc-0123456789abcdef0"
  mount_targets = { a = { subnet_id = "subnet-0123456789abcdef0" } }
}
```

**Consistent names.** The module turns each name into two short forms other resources can be named with: `abbr`, lowercase with words joined by underscores (`Shared Files` becomes `shared_files`), and `machine`, lowercase letters and numbers only (`sharedfiles`), for resources that allow no underscores. It also works out a short form of the Region, such as `use1` for `us-east-1`. Every module derives these the same way, so names stay consistent across a stack. To choose your own short forms, set `scope_abbr`, `purpose_abbr` or `environment_abbr`, for example `environment_abbr = "prd"`.

**One output to reach everything.** All of it comes back in the `metadata` output, along with everything the module created, so a configuration needs only one reference: `module.shared_files.metadata.efs_file_system.dns_name` for the name clients mount, or `module.shared_files.metadata.aws.region.abbr` for the Region's short form.

## Examples

Each example is a complete configuration you can run with `terraform init` and `terraform apply`, given a VPC and subnets.

- [Basic file system](https://github.com/AutomateTheCloud/terraform-aws-efs/tree/main/examples/basic): an encrypted file system that anything in the VPC can mount over TLS.
- [Complete](https://github.com/AutomateTheCloud/terraform-aws-efs/tree/main/examples/complete): most of the module's options, with access limited to one security group and one IAM role.

## Things to know

### Settings that replace the file system

EFS cannot change a file system's encryption key or performance mode. Changing `kms_key_id`, including setting one later, or `performance_mode` replaces the file system, and every file on it is deleted. Choose both before you store data. Throughput, lifecycle transitions, backups, the policy and network access can all be changed in place.

### Network access and the file system policy

Two separate controls decide who can use the file system. `security_group_ingress` decides who can reach the mount targets over the network: the module's security group allows NFS (TCP port 2049) from the sources you list, and nothing else. The file system policy decides what a client that reaches it may do.

Without a policy, EFS lets any client that reaches a mount target mount, write, and act as root. The module's default policy keeps that and adds one rule: clients must use TLS. When you pass your own statements in `policy.source_policy_documents`, the module drops its allow-everyone statement, so only your statements grant access. A client is identified by its IAM role only when it mounts with IAM authorization, the mount helper's `iam` option; otherwise it is anonymous. The [complete example](https://github.com/AutomateTheCloud/terraform-aws-efs/tree/main/examples/complete) grants one IAM role read and write access.

### TLS

With `policy.require_encrypted_transport` on, the default, EFS refuses a client that mounts without TLS, such as a plain `mount -t nfs4`. Install the [EFS mount helper](https://docs.aws.amazon.com/efs/latest/ug/efs-mount-helper.html) (the `amazon-efs-utils` package) and mount with `-o tls`. Turn the requirement off only for clients that cannot use TLS.

### Mount targets

Create one mount target in each Availability Zone your clients run in. EFS allows only one mount target per Availability Zone for each file system, and a client that mounts through a mount target in another zone pays for data transfer between zones. The keys of `mount_targets` are names you choose; changing a key replaces that mount target.

### Storage classes and Archive

Files in the Infrequent Access and Archive storage classes cost less to store and more to read. Archive suits files read a few times a year or less. It needs Elastic throughput and the General Purpose performance mode, and the module checks this at plan time.

### Backups

`automatic_backups` turns on the daily backups EFS makes with AWS Backup, kept for 35 days in the backup vault `aws/efs/automatic-backup-vault`. Destroying the file system does not delete its backups: they are kept, and billed, until they expire.

## Contributing

Contributions are welcome, after review. Read [CONTRIBUTING.md](https://github.com/AutomateTheCloud/terraform-aws-efs/blob/main/CONTRIBUTING.md) before opening a pull request, and report security problems as described in [SECURITY.md](https://github.com/AutomateTheCloud/terraform-aws-efs/blob/main/SECURITY.md).

## Testing

The tests in `tests/` run offline against mocked AWS providers, so they need no AWS account:

```shell
terraform init
terraform test
```

## Reference

The sections below are generated from the code by [terraform-docs](https://terraform-docs.io). To update them, run `terraform-docs .`.

<!-- BEGIN_TF_DOCS -->
### Requirements

The following requirements are needed by this module:

- <a name="requirement_terraform"></a> [terraform](#requirement_terraform) (>= 1.9)

- <a name="requirement_aws"></a> [aws](#requirement_aws) (>= 6.0)

### Required Inputs

The following input variables are required:

#### <a name="input_details"></a> [details](#input_details)

Description: Names and tags shared by every resource in the module. `scope`, `purpose` and `environment` become the `Scope`, `Purpose` and `Environment` tags, and are converted to abbreviations that other modules can use in resource names (see the `metadata` output). [The `details` input](https://github.com/AutomateTheCloud/terraform-aws-efs#the-details-input) explains why it is required.

- `scope` - (Required) What the resource belongs to, such as an organization or project: `Automate the Cloud`.
- `purpose` - (Required) What the resource is for: `Web Site`.
- `environment` - (Required) The environment: `Production`.
- `scope_abbr`, `purpose_abbr`, `environment_abbr` - (Optional) Abbreviations to use instead of the generated ones, which are lowercase with words joined by underscores (`Web Site` becomes `web_site`).
- `additional_tags` - (Optional) More tags for every resource, such as `{ CostCenter = "1234" }`.

Type:

```hcl
object({
    scope            = string
    scope_abbr       = optional(string)
    purpose          = string
    purpose_abbr     = optional(string)
    environment      = string
    environment_abbr = optional(string)
    additional_tags  = optional(map(string), {})
  })
```

#### <a name="input_mount_targets"></a> [mount_targets](#input_mount_targets)

Description: Where clients can reach the file system: one mount target per Availability Zone, each in a subnet of `vpc_id`. The keys are names you choose, such as the Availability Zone (`a`, `b`); they only identify each mount target, so a subnet created in the same configuration can be used.

Each mount target takes:

- `subnet_id` - (Required) The subnet to create the mount target in. Each subnet must be in a different Availability Zone.
- `ip_address` - (Optional) The IPv4 address to give the mount target, from the subnet's range. Without it, AWS picks one.

Changing a mount target's subnet or address replaces that mount target, and clients that mounted through it lose their connection. Adding or removing an entry does not affect the others.

Type:

```hcl
map(object({
    subnet_id  = string
    ip_address = optional(string)
  }))
```

#### <a name="input_vpc_id"></a> [vpc_id](#input_vpc_id)

Description: The ID of the VPC the mount targets are in, such as `vpc-0123456789abcdef0`. The module creates the mount targets' security group in it.

Type: `string`

### Optional Inputs

The following input variables are optional (have default values):

#### <a name="input_automatic_backups"></a> [automatic_backups](#input_automatic_backups)

Description: Turn on automatic daily backups of the file system with AWS Backup, kept for 35 days in the backup vault `aws/efs/automatic-backup-vault`. AWS Backup bills for the backup storage, so this is off by default. It can be turned on or off at any time without replacing the file system.

Type: `bool`

Default: `false`

#### <a name="input_kms_key_id"></a> [kms_key_id](#input_kms_key_id)

Description: ARN of the AWS Key Management Service (KMS) key that encrypts the file system. The file system is always encrypted; without a key, EFS uses the AWS managed key `aws/elasticfilesystem`.

Changing the key, including setting one later, replaces the file system and deletes its data, because EFS cannot change the key of an existing file system.

Type: `string`

Default: `null`

#### <a name="input_lifecycle_policy"></a> [lifecycle_policy](#input_lifecycle_policy)

Description: When files move between storage classes. Files that are not read for a while can move to the cheaper Infrequent Access (IA) and Archive storage classes, which charge for each read. With the default, `{}`, every file stays in Standard storage.

- `transition_to_ia` - (Optional) Move a file to Infrequent Access this long after it was last accessed: `AFTER_1_DAY`, `AFTER_7_DAYS`, `AFTER_14_DAYS`, `AFTER_30_DAYS`, `AFTER_60_DAYS`, `AFTER_90_DAYS`, `AFTER_180_DAYS`, `AFTER_270_DAYS` or `AFTER_365_DAYS`.
- `transition_to_archive` - (Optional) Move a file to Archive this long after it was last accessed, with the same values. Archive needs `throughput.mode = "elastic"` and the `generalPurpose` performance mode.
- `transition_to_primary_storage_class` - (Optional) Set to `AFTER_1_ACCESS` to move a file back to Standard the first time it is read.

Type:

```hcl
object({
    transition_to_ia                    = optional(string)
    transition_to_archive               = optional(string)
    transition_to_primary_storage_class = optional(string)
  })
```

Default: `{}`

#### <a name="input_performance_mode"></a> [performance_mode](#input_performance_mode)

Description: The file system's performance mode: `generalPurpose`, the default and the right choice for almost every workload, or `maxIO`, for thousands of clients at once at the cost of higher latency. `maxIO` cannot be used with Elastic throughput.

Changing it replaces the file system and deletes its data.

Type: `string`

Default: `"generalPurpose"`

#### <a name="input_policy"></a> [policy](#input_policy)

Description: The file system policy, which controls what NFS clients may do. By default the module creates a policy that refuses connections not encrypted with Transport Layer Security (TLS), and otherwise allows what EFS allows with no policy: any client that can reach a mount target may mount, write, and act as root. Network access is still controlled by `security_group_ingress`.

- `require_encrypted_transport` - (Optional) Refuse clients that connect without TLS. Defaults to `true`. Mount with the EFS mount helper's `tls` option (`mount -t efs -o tls`). Set it to `false` only for clients that cannot use TLS.
- `source_policy_documents` - (Optional) Policy documents in JSON, such as from `data.aws_iam_policy_document`, whose statements are added to the policy. When you give any, the module no longer allows every client: only your statements grant access, so they must include an `Allow` for each client that needs one. The [complete example](https://github.com/AutomateTheCloud/terraform-aws-efs/tree/main/examples/complete) grants one IAM role read and write access.

With `require_encrypted_transport = false` and no documents, no policy is created.

Type:

```hcl
object({
    require_encrypted_transport = optional(bool, true)
    source_policy_documents     = optional(list(string), [])
  })
```

Default: `{}`

#### <a name="input_region"></a> [region](#input_region)

Description: The AWS Region to create the file system and everything else in, such as `us-west-2`. Defaults to the Region of the AWS provider passed to the module.

Type: `string`

Default: `null`

#### <a name="input_security_group_ingress"></a> [security_group_ingress](#input_security_group_ingress)

Description: Who can reach the file system over the network. The module creates a security group for the mount targets that allows NFS (TCP port 2049) from each source listed here, and from nothing else. With the default, `{}`, no client can connect. The keys are names you choose; they only identify each rule, so a security group created in the same configuration can be used.

Each source takes exactly one of:

- `cidr_ipv4` - An IPv4 range, such as `10.0.0.0/16`.
- `cidr_ipv6` - An IPv6 range, such as `2001:db8::/56`.
- `security_group_id` - A security group whose members may connect, such as the group of your instances.
- `prefix_list_id` - A managed prefix list of ranges.

and optionally:

- `description` - (Optional) What the source is. Defaults to the key.

Type:

```hcl
map(object({
    cidr_ipv4         = optional(string)
    cidr_ipv6         = optional(string)
    security_group_id = optional(string)
    prefix_list_id    = optional(string)
    description       = optional(string)
  }))
```

Default: `{}`

#### <a name="input_throughput"></a> [throughput](#input_throughput)

Description: How the file system's throughput is set and billed.

- `mode` - (Optional) `bursting`, the default: throughput grows with the amount of data stored, with credits for bursts. `elastic`: throughput scales with the workload, billed for each GB read and written; AWS recommends it for spiky or unpredictable workloads. `provisioned`: a fixed throughput you pay for whether it is used or not.
- `provisioned_mibps` - (Optional) The throughput in MiB per second. Required with `provisioned`, and not allowed otherwise.

The mode can be changed without replacing the file system. AWS allows a change of mode, or a decrease in `provisioned_mibps`, only once every 24 hours.

Type:

```hcl
object({
    mode              = optional(string, "bursting")
    provisioned_mibps = optional(number)
  })
```

Default: `{}`

### Outputs

The following outputs are exported:

#### <a name="output_metadata"></a> [metadata](#output_metadata)

Description: Everything the module created, in one object, so that other configurations need only one reference:

- `details` - The scope, purpose and environment, each with its `name`, `abbr` (lowercase, words joined by underscores) and `machine` (lowercase letters and numbers only) forms, and the `tags` applied to every resource.
- `aws` - The `account.id`, and the `region` `name`, `abbr` (such as `use1` for `us-east-1`) and `description`.
- `efs_file_system` - The file system's `id`, `arn`, `dns_name` (the name clients mount), `encrypted`, `kms_key_id`, `performance_mode`, `throughput_mode`, `lifecycle_policy`, `size_in_bytes`, `tags` and the rest of its attributes.
- `efs_mount_target` - The mount targets, keyed like `mount_targets`, each with its `id`, `subnet_id`, `ip_address`, `availability_zone_name`, `mount_target_dns_name` and `network_interface_id`.
- `security_group` - The mount targets' security group, with its `id`, `arn` and `name`.
- `vpc_security_group_ingress_rule` - The ingress rules, keyed like `security_group_ingress`, or `null` when there are none.
- `efs_backup_policy` - The backup setting, with `backup_policy[0].status`.
- `efs_file_system_policy` - The file system policy, with its `policy` JSON, or `null` when no policy is created.
<!-- END_TF_DOCS -->

## License

This module is licensed under the [Apache License 2.0](https://github.com/AutomateTheCloud/terraform-aws-efs/blob/main/LICENSE). See [NOTICE](https://github.com/AutomateTheCloud/terraform-aws-efs/blob/main/NOTICE) for the copyright notice.

The Automate the Cloud name and logo are not covered by this license.

---

Maintained by [Automate the Cloud](https://automatethe.cloud), a Kentucky 501(c)(3) that teaches cloud infrastructure and helps nonprofits run theirs.
