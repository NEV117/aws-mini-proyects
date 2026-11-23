data "aws_availability_zones" "available" {
  state = "available"
}

# Default subnet of the chosen AZ, used when subnet_id is not set
data "aws_subnet" "default" {
  count = var.subnet_id == null ? 1 : 0

  availability_zone = local.availability_zone
  default_for_az    = true
}

data "aws_subnet" "selected" {
  id = local.subnet_id
}

# No inbound rules unless allowed_vnc_cidr is set. Outbound is required
# for the SSM agent to reach Systems Manager.
resource "aws_security_group" "mac" {
  name_prefix = "${var.name_prefix}-mac-"
  description = "macOS instance - VNC only when allowed_vnc_cidr is set"
  vpc_id      = data.aws_subnet.selected.vpc_id

  dynamic "ingress" {
    for_each = var.allowed_vnc_cidr == null ? [] : [var.allowed_vnc_cidr]
    content {
      description = "Screen Sharing (VNC)"
      from_port   = 5900
      to_port     = 5900
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
    }
  }

  egress {
    description = "All outbound (SSM, updates)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
}
