resource "aws_security_group_rule" "ingress" {
  for_each                 = toset(var.security_group_access)
  security_group_id        = aws_security_group.this.id
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = 2049
  to_port                  = 2049
  cidr_blocks              = can(cidrnetmask(each.key)) == true ? [each.key] : null
  source_security_group_id = can(cidrnetmask(each.key)) == false ? each.key : null
  description              = "Allow access from ${each.key}"
  provider                 = aws.this
}

resource "aws_security_group_rule" "egress" {
  for_each                 = toset(var.security_group_access)
  security_group_id        = aws_security_group.this.id
  type                     = "egress"
  protocol                 = "tcp"
  from_port                = 2049
  to_port                  = 2049
  cidr_blocks              = can(cidrnetmask(each.key)) == true ? [each.key] : null
  source_security_group_id = can(cidrnetmask(each.key)) == false ? each.key : null
  description              = "Allow access to ${each.key}"
  provider                 = aws.this
}