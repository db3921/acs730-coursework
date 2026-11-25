output "vpc_id" {
  description = "Id of this environment's VPC."
  value       = aws_vpc.main.id
}

output "subnet_ids" {
  description = "Public subnet ids, keyed like var.public_subnets."
  value       = { for key, subnet in aws_subnet.public : key => subnet.id }
}

output "instance_id" {
  description = "Id of the web server instance."
  value       = aws_instance.web.id
}

output "web_public_ip" {
  description = "Public IP of the web server."
  value       = aws_instance.web.public_ip
}

output "web_url" {
  description = "URL to curl once the instance has booted."
  value       = "http://${aws_instance.web.public_ip}/"
}

output "alarm_name" {
  description = "Name of the CloudWatch CPU alarm."
  value       = aws_cloudwatch_metric_alarm.cpu_high.alarm_name
}

output "app_secret_parameter" {
  description = "Name (not value) of the SSM parameter this environment reads."
  value       = data.aws_ssm_parameter.app_secret.name
}

output "app_secret_version" {
  description = "Version of the SSM parameter at apply time."
  value       = data.aws_ssm_parameter.app_secret.version
}
