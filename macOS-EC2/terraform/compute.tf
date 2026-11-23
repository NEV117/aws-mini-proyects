data "aws_ssm_parameter" "mac_ami" {
  name = var.mac_ami_ssm_parameter
}

# Existing host, when host_id is set (allocated outside Terraform)
data "aws_ec2_host" "existing" {
  count   = var.host_id == null ? 0 : 1
  host_id = var.host_id
}

# Dedicated host required for macOS instances (24 h minimum allocation).
# Created only when host_id is not set.
resource "aws_ec2_host" "mac" {
  count = var.host_id == null ? 1 : 0

  availability_zone = local.availability_zone
  instance_type     = var.instance_type

  tags = {
    Name = "${var.name_prefix}-mac-host"
  }
}

resource "aws_instance" "mac" {
  ami                    = data.aws_ssm_parameter.mac_ami.insecure_value
  instance_type          = var.instance_type
  host_id                = local.host_id
  tenancy                = "host"
  subnet_id              = local.subnet_id
  vpc_security_group_ids = [aws_security_group.mac.id]
  iam_instance_profile   = aws_iam_instance_profile.mac.name

  user_data = templatefile("${path.module}/user_data.sh.tftpl", {
    remote_username      = var.remote_username
    remote_user_password = var.remote_user_password
  })

  tags = {
    Name = "${var.name_prefix}-mac"
  }

  lifecycle {
    # A new macOS AMI release would otherwise replace the instance
    ignore_changes = [ami]

    precondition {
      condition     = data.aws_subnet.selected.availability_zone == local.availability_zone
      error_message = "subnet_id must be in availability_zone (the dedicated host's AZ)."
    }

    precondition {
      condition     = var.host_id == null || one(data.aws_ec2_host.existing[*].instance_type) == var.instance_type
      error_message = "The host in host_id must be allocated for instance_type (mac2.metal by default)."
    }
  }
}

# The host became count-based when host_id was added
moved {
  from = aws_ec2_host.mac
  to   = aws_ec2_host.mac[0]
}
