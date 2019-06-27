
// VPC
resource "aws_vpc" "vpc" {
  cidr_block = "${var.vpc_cidr}"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags {
    Name = "${var.environment}-vpc"
  }
}

// Public subnet
resource "aws_subnet" "public_sn" {
  count = "${length(var.public_sn_cidr)}"
  cidr_block = "${element(var.public_sn_cidr, count.index)}"
  vpc_id = "${aws_vpc.vpc.id}"
  availability_zone = "${element(var.availability_zone, count.index)}"

  tags {
    Name = "${var.environment}-${element(var.availability_zone, count.index)}-public-sn"
  }
}

// routing table for public sn
resource "aws_route_table" "public_rt" {
  vpc_id = "${aws_vpc.vpc.id}"

  tags {
    Name = "${var.environment}-public-sn-routing-table"
  }

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.igw.id}"
  }
}

// rt association for public sn
resource "aws_route_table_association" "public" {
  count = "${length(var.public_sn_cidr)}"
  subnet_id = "${element(aws_subnet.public_sn.*.id, count.index)}"
  route_table_id = "${aws_route_table.public_rt.id}"
}


// Private subnet
resource "aws_subnet" "private_sn" {
  count = "${length(var.private_sn_cidr)}"
  cidr_block = "${element(var.private_sn_cidr, count.index)}"
  vpc_id = "${aws_vpc.vpc.id}"
  availability_zone = "${element(var.availability_zone, count.index)}"

  tags {
    Name = "${var.environment}-${element(var.availability_zone, count.index)}-private-sn"
  }
}

// routing table for private rt
resource "aws_route_table" "private_rt" {
  vpc_id = "${aws_vpc.vpc.id}"

  tags {
    Name = "${var.environment}-private-sn-routing-table"
  }

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = "${aws_nat_gateway.nat_gw.id}"
  }
}

// rt association for private sn
resource "aws_route_table_association" "private" {
  count = "${length(var.public_sn_cidr)}"
  subnet_id = "${element(aws_subnet.private_sn.*.id, count.index)}"
  route_table_id = "${aws_route_table.private_rt.id}"
}

// internet gateway for public subnet
resource "aws_internet_gateway" "igw" {
  vpc_id = "${aws_vpc.vpc.id}"
  tags {
    Name = "${var.environment}-igw"
  }
}

// EIP for NAT
resource "aws_eip" "nat_eip" {
  vpc = true
}

// NAT in pub sn
resource "aws_nat_gateway" "nat_gw" {
  allocation_id = "${aws_eip.nat_eip.id}"
  subnet_id = "${element(aws_subnet.public_sn.*.id, 0)}"
  depends_on = ["aws_internet_gateway.igw"]

  tags = {
    Name = "${var.environment}-${element(var.availability_zone, count.index)}-nat"
  }
}

// default security group: allow all traffic can change to ingress traffic to certain port
resource "aws_security_group" "default-sg" {
  name = "${var.environment}-default-security-group"
  description = "security group for load balancer"
  vpc_id = "${aws_vpc.vpc.id}"
  depends_on = ["aws_vpc.vpc"]

  ingress {
    from_port = 0
    protocol = "-1"
    to_port = 0
    self = true
  }

  egress {
    from_port = 0
    protocol = "-1"
    to_port = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}




