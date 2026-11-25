# Task 7: CPU reports every 5 minutes even on an idle instance, so this
# alarm leaves INSUFFICIENT_DATA and settles at OK about 10-15 minutes
# after the instance starts. A request-count metric would not.
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "${local.name}-cpu-high"
  alarm_description   = "Average CPU on ${local.name}-web above ${var.alarm_cpu_threshold}% for 10 minutes"
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = var.alarm_cpu_threshold
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "missing"

  dimensions = {
    InstanceId = aws_instance.web.id
  }

  tags = merge(local.common_tags, { Name = "${local.name}-cpu-high" })
}
