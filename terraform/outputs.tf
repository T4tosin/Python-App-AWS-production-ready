output "instance_public_ip" {
  description = "Public IP of the EC2 instance"
  value       = module.ec2.public_ip
}

output "instance_public_dns" {
  description = "Public DNS of the EC2 instance"
  value       = module.ec2.public_dns
}

output "app_url" {
  description = "Application URL"
  value       = "http://${module.ec2.public_ip}:5000"
}

output "health_check_url" {
  description = "Health check endpoint"
  value       = "http://${module.ec2.public_ip}:5000/health"
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "ssh_command" {
  description = "SSH command to connect to the instance"
  value       = var.key_name != "" ? "ssh -i ~/.ssh/${var.key_name}.pem ec2-user@${module.ec2.public_ip}" : "No key pair configured"
}
