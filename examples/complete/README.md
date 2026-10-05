# Complete

Most of the module's options together, for an application whose instances share a file system:

- A customer managed AWS Key Management Service (KMS) key encrypts the file system.
- Elastic throughput, which scales with the workload and is billed for each GB read and written.
- Files move to Infrequent Access after 30 days without being read, to Archive after 90, and back to Standard the first time they are read.
- Automatic daily backups with AWS Backup.
- Only members of the application's security group can reach the file system over the network.
- The file system policy lets only the application's IAM role mount and write, and refuses clients that do not use Transport Layer Security (TLS).

The example creates the KMS key, the application's security group and its IAM role. It does not create instances.

## Run it

Choose a VPC and one subnet in each of the Availability Zones your instances use:

```shell
terraform init
terraform apply -var 'vpc_id=vpc-0123456789abcdef0' -var 'subnet_ids=["subnet-0123456789abcdef0","subnet-0fedcba9876543210"]'
```

An instance needs the application's security group and an instance profile for its role, then mounts with IAM authorization:

```shell
sudo mount -t efs -o tls,iam <file system id>:/ /mnt/efs
```

Remove it with `terraform destroy` and the same `-var` options. Destroying the file system deletes every file on it; AWS Backup keeps the recovery points it made until they expire, and bills for them. KMS deletes the key after a seven-day waiting period.

<!-- BEGIN_TF_DOCS -->
### Requirements

The following requirements are needed by this module:

- <a name="requirement_terraform"></a> [terraform](#requirement_terraform) (>= 1.9)

- <a name="requirement_aws"></a> [aws](#requirement_aws) (~> 6.0)

### Required Inputs

The following input variables are required:

#### <a name="input_subnet_ids"></a> [subnet_ids](#input_subnet_ids)

Description: IDs of the subnets for the mount targets, one in each Availability Zone

Type: `list(string)`

#### <a name="input_vpc_id"></a> [vpc_id](#input_vpc_id)

Description: ID of the VPC to create the file system in

Type: `string`

### Outputs

The following outputs are exported:

#### <a name="output_file_system"></a> [file_system](#output_file_system)

Description: The file system, and the security group and role the application uses with it
<!-- END_TF_DOCS -->
