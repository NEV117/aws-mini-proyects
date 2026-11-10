locals {
  # Compliance tags required on every resource.
  common_tags = {
    Service     = var.service
    Environment = var.environment
    Team        = var.team
    Owner       = var.owner
  }

  name     = "${var.name_prefix}-${var.environment}"
  asg_name = "${local.name}-asg"

  # Namespace of the custom CloudWatch metric the servers publish.
  metric_namespace = "MinecraftServer"
  metric_name      = "PlayersOnline"

  # CloudWatch log groups the agent on each server writes to.
  server_log_groups = {
    server        = "/${var.name_prefix}/${var.environment}/server"
    bootstrap     = "/${var.name_prefix}/${var.environment}/bootstrap"
    player_metric = "/${var.name_prefix}/${var.environment}/player-metric"
  }
}
