resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "${var.project_name}-alb-5xx"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_ELB_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 5
  dimensions = {
    LoadBalancer = replace(var.alb_arn, "arn:aws:elasticloadbalancing:${var.aws_region}:", "")
  }
}

resource "aws_cloudwatch_metric_alarm" "ecs_cpu_high" {
  alarm_name          = "${var.project_name}-ecs-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 60
  statistic           = "Average"
  threshold           = 80
  dimensions = { ClusterName = var.ecs_cluster_name }
}

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-dashboard"
  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric", x = 0, y = 0, width = 12, height = 6,
        properties = {
          metrics = [["AWS/ECS","CPUUtilization","ClusterName",var.ecs_cluster_name]],
          period  = 60, stat = "Average", title = "ECS Cluster CPU"
        }
      },
      {
        type = "metric", x = 12, y = 0, width = 12, height = 6,
        properties = {
          metrics = [["AWS/ApplicationELB","HTTPCode_ELB_5XX_Count","LoadBalancer", replace(var.alb_arn, "arn:aws:elasticloadbalancing:${var.aws_region}:", "") ]],
          period  = 60, stat = "Sum", title = "ALB 5xx"
        }
      }
    ]
  })
}
