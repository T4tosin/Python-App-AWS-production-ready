# monitoring/cloudwatch.tf
# Deploy this alongside your main Terraform or include in root main.tf

resource "aws_cloudwatch_log_group" "app" {
  name              = "/${var.project_name}/${var.environment}/app"
  retention_in_days = 7

  tags = {
    Name        = "${var.project_name}-${var.environment}-app-logs"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_log_group" "bootstrap" {
  name              = "/${var.project_name}/${var.environment}/bootstrap"
  retention_in_days = 3
}

# ── Metric Alarms ─────────────────────────────────────────────────────────────

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "${var.project_name}-${var.environment}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "EC2 CPU usage exceeded 80%"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    InstanceId = var.instance_id
  }
}

resource "aws_cloudwatch_metric_alarm" "memory_high" {
  alarm_name          = "${var.project_name}-${var.environment}-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "mem_used_percent"
  namespace           = "CWAgent"
  period              = 120
  statistic           = "Average"
  threshold           = 85
  alarm_description   = "Memory usage exceeded 85%"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    InstanceId  = var.instance_id
    Environment = var.environment
  }
}

resource "aws_cloudwatch_metric_alarm" "disk_high" {
  alarm_name          = "${var.project_name}-${var.environment}-disk-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "disk_used_percent"
  namespace           = "CWAgent"
  period              = 300
  statistic           = "Average"
  threshold           = 90
  alarm_description   = "Disk usage exceeded 90%"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    InstanceId  = var.instance_id
    Environment = var.environment
    path        = "/"
    device      = "xvda1"
    fstype      = "xfs"
  }
}

# ── CloudWatch Dashboard ──────────────────────────────────────────────────────

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-${var.environment}"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0; y = 0; width = 12; height = 6
        properties = {
          title  = "CPU Utilization"
          period = 60
          stat   = "Average"
          metrics = [["AWS/EC2", "CPUUtilization", "InstanceId", var.instance_id]]
          view   = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 12; y = 0; width = 12; height = 6
        properties = {
          title  = "Memory Used %"
          period = 60
          stat   = "Average"
          metrics = [["CWAgent", "mem_used_percent", "InstanceId", var.instance_id, "Environment", var.environment]]
          view   = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 0; y = 6; width = 12; height = 6
        properties = {
          title  = "Network In/Out"
          period = 60
          stat   = "Sum"
          metrics = [
            ["AWS/EC2", "NetworkIn", "InstanceId", var.instance_id],
            ["AWS/EC2", "NetworkOut", "InstanceId", var.instance_id]
          ]
          view = "timeSeries"
        }
      },
      {
        type   = "log"
        x      = 12; y = 6; width = 12; height = 6
        properties = {
          title   = "Application Logs"
          query   = "SOURCE '/${var.project_name}/${var.environment}/app' | fields @timestamp, @message | sort @timestamp desc | limit 50"
          region  = var.aws_region
          view    = "table"
        }
      }
    ]
  })
}

# ── SNS Topic for Alerts ──────────────────────────────────────────────────────

resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-${var.environment}-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  count     = var.alert_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# ── Variables ─────────────────────────────────────────────────────────────────

variable "instance_id" {
  description = "EC2 instance ID to monitor"
  type        = string
  default     = ""
}

variable "alert_email" {
  description = "Email address for CloudWatch alarm notifications"
  type        = string
  default     = ""
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}
