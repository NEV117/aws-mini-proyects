output "instance_id" {
  description = "EC2 macOS instance ID"
  value       = aws_instance.mac.id
}

output "host_id" {
  description = "Dedicated host ID (releasable only 24 h after allocation; not released by Terraform when passed in as host_id)"
  value       = local.host_id
}

output "public_ip" {
  description = "Public IP (empty if the subnet does not auto-assign public IPs)"
  value       = aws_instance.mac.public_ip
}

output "screen_sharing_tunnel_command" {
  description = "Run locally, then open vnc://localhost:5900"
  value       = "aws ssm start-session --region ${var.region} --target ${aws_instance.mac.id} --document-name AWS-StartPortForwardingSession --parameters portNumber=5900,localPortNumber=5900"
}
