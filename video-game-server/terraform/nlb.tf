# One public address for players. The NLB spreads new connections across the
# servers in the Auto Scaling group.

resource "aws_lb" "game" {
  name                             = "${local.name}-nlb"
  load_balancer_type               = "network"
  internal                         = false
  subnets                          = aws_subnet.public[*].id
  enable_cross_zone_load_balancing = true
}

resource "aws_lb_target_group" "game" {
  name        = "${local.name}-tg"
  port        = var.server_port
  protocol    = "TCP"
  vpc_id      = aws_vpc.main.id
  target_type = "instance"

  # Give players time to finish before an instance is removed.
  deregistration_delay = 60

  # Each server has its own world, so a player who reconnects should land on
  # the same server.
  stickiness {
    enabled = true
    type    = "source_ip"
  }

  health_check {
    protocol            = "TCP"
    port                = "traffic-port"
    interval            = 30
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }
}

resource "aws_lb_listener" "game" {
  load_balancer_arn = aws_lb.game.arn
  port              = var.server_port
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.game.arn
  }
}
