# Interface VPC endpoints for Systems Manager. With them, the SSM agent
# reaches Systems Manager over private IPs inside the VPC, so the shell and
# the Screen Sharing tunnel keep working even when the instance has no
# internet egress. Private DNS needs enableDnsSupport and enableDnsHostnames
# on the VPC (both are on in the default VPC).

locals {
  ssm_endpoint_services = var.enable_ssm_vpc_endpoints ? toset(["ssm", "ssmmessages", "ec2messages"]) : toset([])
}

# Lets the instance reach the endpoints over HTTPS
resource "aws_security_group" "ssm_endpoints" {
  count = var.enable_ssm_vpc_endpoints ? 1 : 0

  name_prefix = "${var.name_prefix}-ssm-endpoints-"
  description = "SSM VPC endpoints - HTTPS from the macOS instance"
  vpc_id      = data.aws_subnet.selected.vpc_id

  tags = {
    Name = "${var.name_prefix}-ssm-endpoints"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "ssm_endpoints_https" {
  count = var.enable_ssm_vpc_endpoints ? 1 : 0

  security_group_id            = aws_security_group.ssm_endpoints[0].id
  description                  = "HTTPS from the macOS instance"
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  referenced_security_group_id = aws_security_group.mac.id
}

resource "aws_vpc_endpoint" "ssm" {
  for_each = local.ssm_endpoint_services

  vpc_id              = data.aws_subnet.selected.vpc_id
  service_name        = "com.amazonaws.${var.region}.${each.key}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [local.subnet_id]
  security_group_ids  = [aws_security_group.ssm_endpoints[0].id]
  private_dns_enabled = true

  tags = {
    Name = "${var.name_prefix}-${each.key}"
  }
}
