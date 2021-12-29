data "aws_availability_zones" "available" {
  state     = "available"

  filter {
    name    = "opt-in-status"
    values  = ["opt-in-not-required"]
  }
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_security_group" "demo" {
  name = "demo"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8
    to_port     = 0
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

locals {
  pub_subnets   = zipmap(var.avail_zones,
                         [for i in range(1, length(var.avail_zones)+1) :
                          cidrsubnet(aws_vpc.main.cidr_block, 8, i)]
                        )
  priv_subnets  = zipmap(var.avail_zones,
                         [for i in range(length(var.avail_zones)+1,
                                         length(var.avail_zones)*2 + 1) :
                          cidrsubnet(aws_vpc.main.cidr_block, 8, i)]
                        )
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "pub" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
}

resource "aws_subnet" "pub" {
  for_each                = toset(var.avail_zones)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = local.pub_subnets[each.key]
  availability_zone       = each.key
  map_public_ip_on_launch = true

  tags = {
    Name = each.key
  }
}

resource "aws_route_table_association" "pub" {
  for_each        = toset(var.avail_zones)
  subnet_id       = aws_subnet.pub[each.key].id
  route_table_id  = aws_route_table.pub.id
}

resource "aws_subnet" "priv" {
  for_each          = toset(var.avail_zones)
  vpc_id            = aws_vpc.main.id
  cidr_block        = local.priv_subnets[each.key]
  availability_zone = each.key

  tags = {
    Name = each.key
  }
}

resource "aws_eip" "eip" {
  for_each                = toset(var.avail_zones)
  vpc                     = true
  depends_on              = [aws_internet_gateway.main]

  tags = {
    Name = each.key
  }
}

resource "aws_nat_gateway" "nat" {
  for_each      = toset(var.avail_zones)
  allocation_id = aws_eip.eip[each.key].id
  subnet_id     = aws_subnet.pub[each.key].id
  depends_on    = [aws_internet_gateway.main]

  tags = {
    Name = each.key
  }
}

resource "aws_route_table" "priv" {
  for_each  = toset(var.avail_zones)
  vpc_id    = aws_vpc.main.id

  route {
   cidr_block     = "0.0.0.0/0"
   nat_gateway_id = aws_nat_gateway.nat[each.key].id
  }
}

resource "aws_route_table_association" "priv" {
  for_each        = toset(var.avail_zones)
  subnet_id       = aws_subnet.priv[each.key].id
  route_table_id  = aws_route_table.priv[each.key].id
}
