resource "aws_efs_file_system" "this" {
  encrypted                       = try(var.encryption.enabled, true)
  kms_key_id                      = try(var.encryption.kms_key_id, null)
  performance_mode                = var.performance_mode
  throughput_mode                 = (var.provisioned_throughput == null ? "bursting" : "provisioned")
  provisioned_throughput_in_mibps = var.provisioned_throughput

  dynamic "lifecycle_policy" {
    for_each = (var.lifecycle_transition_to_ia != "" ? [1] : [])
    content {
      transition_to_ia = var.lifecycle_transition_to_ia
    }
  }

  tags = merge(
    local.tags,
    tomap({
      "Name" = "${local.scope.abbr}-${local.purpose.abbr}-${local.environment.abbr}-${local.aws.region.abbr}-efs"
    })
  )
  provider = aws.this
}
