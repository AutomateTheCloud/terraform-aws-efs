# Basic file system

An encrypted Amazon Elastic File System (EFS) file system with a mount target in each subnet you give. Anything in the VPC can reach it over NFS, and every client must connect with Transport Layer Security (TLS).

Everything else uses the module's defaults: the AWS managed encryption key, General Purpose performance, Bursting throughput, no lifecycle transitions, and automatic backups off.

## Run it

Choose a VPC and one subnet in each of the Availability Zones your clients use:

```shell
terraform init
terraform apply -var 'vpc_id=vpc-0123456789abcdef0' -var 'subnet_ids=["subnet-0123456789abcdef0","subnet-0fedcba9876543210"]'
```

Mount it from an instance in the VPC with the [EFS mount helper](https://docs.aws.amazon.com/efs/latest/ug/efs-mount-helper.html):

```shell
sudo mount -t efs -o tls <file system id>:/ /mnt/efs
```

Remove it with `terraform destroy` and the same `-var` options. Destroying the file system deletes every file on it.

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

Description: ID and DNS name of the file system
<!-- END_TF_DOCS -->
