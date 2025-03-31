resource "aws_efs_mount_target" "this" {
  count          = (length(var.subnets))
  file_system_id = aws_efs_file_system.this.id
  subnet_id      = data.aws_subnet.this[count.index].id
  security_groups = [
    aws_security_group.this.id
  ]
  provider = aws.this
}
