data "aws_subnet" "this" {
  count    = (length(var.subnets))
  vpc_id   = data.aws_vpc.this.id
  id       = var.subnets[count.index]
  provider = aws.this
}

data "aws_vpc" "this" {
  id       = var.vpc_id
  provider = aws.this
}
