output "server_address" {
  description = "Address to add in Minecraft under Multiplayer > Add Server"
  value       = "${aws_lb.game.dns_name}:${var.server_port}"
}

output "autoscaling_group_name" {
  description = "Name of the Auto Scaling group running the game servers"
  value       = aws_autoscaling_group.server.name
}

output "player_metric" {
  description = "CloudWatch metric used for scaling"
  value       = "${local.metric_namespace}/${local.metric_name} (AutoScalingGroupName=${aws_autoscaling_group.server.name})"
}

output "log_groups" {
  description = "CloudWatch log groups for the servers and the VPC"
  value = merge(
    { for key, group in aws_cloudwatch_log_group.server : key => group.name },
    var.enable_vpc_flow_logs ? { vpc_flow = aws_cloudwatch_log_group.vpc_flow[0].name } : {}
  )
}

output "compliance_tags" {
  description = "Tags applied to every resource"
  value       = local.common_tags
}
