data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_launch_template" "server" {
  name_prefix   = "${local.name}-lt-"
  image_id      = data.aws_ssm_parameter.al2023_ami.value
  instance_type = var.instance_type

  iam_instance_profile {
    arn = aws_iam_instance_profile.server.arn
  }

  vpc_security_group_ids = [aws_security_group.server.id]

  # Require IMDSv2.
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = var.root_volume_size_gb
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  user_data = base64encode(templatefile("${path.module}/user_data.sh.tftpl", {
    minecraft_version = var.minecraft_version
    server_port       = var.server_port
    max_players       = var.max_players_per_server
    motd              = var.motd
    difficulty        = var.difficulty
    java_heap_mb      = var.java_heap_mb
    asg_name          = local.asg_name
    metric_namespace  = local.metric_namespace
    metric_name       = local.metric_name

    # Referencing the resources makes the log groups exist before any server starts.
    server_log_group        = aws_cloudwatch_log_group.server["server"].name
    bootstrap_log_group     = aws_cloudwatch_log_group.server["bootstrap"].name
    player_metric_log_group = aws_cloudwatch_log_group.server["player_metric"].name
  }))

  # Instances and volumes launched by the ASG do not get provider default_tags,
  # so the compliance tags are set here explicitly.
  tag_specifications {
    resource_type = "instance"
    tags          = merge(local.common_tags, { Name = "${local.name}-server" })
  }

  tag_specifications {
    resource_type = "volume"
    tags          = merge(local.common_tags, { Name = "${local.name}-server-volume" })
  }

  tag_specifications {
    resource_type = "network-interface"
    tags          = merge(local.common_tags, { Name = "${local.name}-server-eni" })
  }
}

resource "aws_autoscaling_group" "server" {
  name                = local.asg_name
  min_size            = var.min_servers
  max_size            = var.max_servers
  desired_capacity    = var.desired_servers
  vpc_zone_identifier = aws_subnet.public[*].id
  target_group_arns   = [aws_lb_target_group.game.arn]

  # Replace servers that stop answering on the game port.
  health_check_type         = "ELB"
  health_check_grace_period = 300

  # Minecraft needs a few minutes to install and generate the world before its
  # metrics are meaningful.
  default_instance_warmup = 300

  launch_template {
    id      = aws_launch_template.server.id
    version = aws_launch_template.server.latest_version
  }

  enabled_metrics = [
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupTotalInstances",
  ]

  # provider default_tags do not apply to Auto Scaling groups.
  dynamic "tag" {
    for_each = merge(local.common_tags, { Name = "${local.name}-server" })

    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = false # the launch template already tags instances
    }
  }

  lifecycle {
    # Let the scaling policies change capacity without Terraform resetting it.
    ignore_changes = [desired_capacity]
  }
}

# ---------------------------------------------------------------------------
# Horizontal scaling
#
# Two target tracking policies. The group scales out when either one is above
# its target, and scales in only when both are below.
# ---------------------------------------------------------------------------

# Players per server, published every minute by each instance (see user data).
resource "aws_autoscaling_policy" "players" {
  name                   = "${local.name}-players-per-server"
  autoscaling_group_name = aws_autoscaling_group.server.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    target_value = var.target_players_per_server

    customized_metric_specification {
      namespace   = local.metric_namespace
      metric_name = local.metric_name
      statistic   = "Average"
      unit        = "Count"

      metric_dimension {
        name  = "AutoScalingGroupName"
        value = aws_autoscaling_group.server.name
      }
    }
  }
}

# CPU, as a fallback when a few players load many chunks.
resource "aws_autoscaling_policy" "cpu" {
  name                   = "${local.name}-cpu"
  autoscaling_group_name = aws_autoscaling_group.server.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    target_value = var.target_cpu_percent

    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
  }
}
