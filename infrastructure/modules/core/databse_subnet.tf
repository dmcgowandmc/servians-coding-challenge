resource "aws_subnet" "storage" {
  count = var.vpc_az_size

  vpc_id = aws_vpc.servian_test_vpc.id

  availability_zone               = data.aws_availability_zones.available.names[count.index]
  cidr_block                      = var.vpc_subnet_database_cidr[count.index]
  assign_ipv6_address_on_creation = false

  tags = merge(var.default_tags, {
    "Name"                                    = "${var.env_prefix}-subnet-storage-${data.aws_availability_zones.available.names[count.index]}"
    "kubernetes.io/cluster/${var.env_prefix}" = "owned"
  })
}

resource "aws_route_table" "storage" {
  vpc_id = aws_vpc.servian_test_vpc.id

  tags = merge(var.default_tags, {
    "Name" = "${var.env_prefix}-storage-rt"
  })
}

resource "aws_route_table_association" "storage_assoc" {
  count = var.vpc_az_size

  subnet_id      = element(aws_subnet.storage.*.id, count.index)
  route_table_id = aws_route_table.storage.id
}
