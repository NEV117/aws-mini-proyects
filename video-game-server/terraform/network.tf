# Public subnets only (no NAT gateway) to keep the project cheap. The instances
# get public IPs so they can download Java and the server jar, but the security
# group only opens the game port.

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "${local.name}-vpc" }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = { Name = "${local.name}-igw" }
}

resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = { Name = "${local.name}-public-${count.index + 1}" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = { Name = "${local.name}-public-rt" }
}

resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "server" {
  name        = "${local.name}-server-sg"
  description = "Minecraft game servers"
  vpc_id      = aws_vpc.main.id

  tags = { Name = "${local.name}-server-sg" }
}

# The NLB keeps the client's IP, so players' addresses must be allowed here.
resource "aws_vpc_security_group_ingress_rule" "players" {
  for_each = toset(var.allowed_player_cidrs)

  security_group_id = aws_security_group.server.id
  description       = "Minecraft players"
  ip_protocol       = "tcp"
  from_port         = var.server_port
  to_port           = var.server_port
  cidr_ipv4         = each.value
}

# NLB health checks come from the load balancer's private IPs inside the VPC.
resource "aws_vpc_security_group_ingress_rule" "nlb_health_check" {
  security_group_id = aws_security_group.server.id
  description       = "NLB health checks"
  ip_protocol       = "tcp"
  from_port         = var.server_port
  to_port           = var.server_port
  cidr_ipv4         = aws_vpc.main.cidr_block
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.server.id
  description       = "Outbound for package installs, server download and CloudWatch"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}
