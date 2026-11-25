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

output "ssm_vpc_endpoint_ids" {
  description = "IDs of the SSM interface VPC endpoints, by service (empty when enable_ssm_vpc_endpoints is false)"
  value       = { for service, endpoint in aws_vpc_endpoint.ssm : service => endpoint.id }
}

output "screen_sharing_tunnel_command" {
  description = "Run locally, then open vnc://localhost:5900"
  value       = "aws ssm start-session --region ${var.region} --target ${aws_instance.mac.id} --document-name AWS-StartPortForwardingSession --parameters portNumber=5900,localPortNumber=5900"
}
