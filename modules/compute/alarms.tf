# CloudWatch alarms for compute resources

locals {
  alarm_actions = var.alarm_sns_topic_arn != "" ? [var.alarm_sns_topic_arn] : []
}

# 1. API Lambda 5xx errors (via API Gateway)
resource "aws_cloudwatch_metric_alarm" "api_5xx_errors" {
  alarm_name          = "cosmonaut-${var.env}-api-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "5XXError"
  namespace           = "AWS/ApiGateway"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  treat_missing_data  = "notBreaching"

  dimensions = {
    ApiId = aws_apigatewayv2_api.main.id
    Stage = aws_apigatewayv2_stage.main.name
  }

  alarm_description = "API Gateway 5xx error rate for cosmonaut-${var.env} API"
  alarm_actions     = local.alarm_actions
}

# 2. Fast Worker Lambda errors
resource "aws_cloudwatch_metric_alarm" "worker_fast_errors" {
  alarm_name          = "cosmonaut-${var.env}-worker-fast-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.worker_fast.function_name
  }

  alarm_description = "Fast worker Lambda errors for cosmonaut-${var.env}"
  alarm_actions     = local.alarm_actions
}

# 3. Slow Worker Lambda errors
resource "aws_cloudwatch_metric_alarm" "worker_slow_errors" {
  alarm_name          = "cosmonaut-${var.env}-worker-slow-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.worker_slow.function_name
  }

  alarm_description = "Slow worker Lambda errors for cosmonaut-${var.env}"
  alarm_actions     = local.alarm_actions
}

# 4. SQS Fast queue - high message age (oldest message too old)
resource "aws_cloudwatch_metric_alarm" "sqs_fast_queue_age" {
  alarm_name          = "cosmonaut-${var.env}-sqs-fast-queue-age"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "ApproximateAgeOfOldestMessage"
  namespace           = "AWS/SQS"
  period              = 300
  statistic           = "Maximum"
  threshold           = 600 # 10 minutes
  treat_missing_data  = "notBreaching"

  dimensions = {
    QueueName = aws_sqs_queue.fast.name
  }

  alarm_description = "Fast SQS queue has messages older than 10 minutes for cosmonaut-${var.env}"
  alarm_actions     = local.alarm_actions
}

# 5. SQS Slow queue - high message age (oldest message too old)
resource "aws_cloudwatch_metric_alarm" "sqs_slow_queue_age" {
  alarm_name          = "cosmonaut-${var.env}-sqs-slow-queue-age"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "ApproximateAgeOfOldestMessage"
  namespace           = "AWS/SQS"
  period              = 300
  statistic           = "Maximum"
  threshold           = 1800 # 30 minutes (slow queue has 15min timeout, so 30min indicates backlog)
  treat_missing_data  = "notBreaching"

  dimensions = {
    QueueName = aws_sqs_queue.slow.name
  }

  alarm_description = "Slow SQS queue has messages older than 30 minutes for cosmonaut-${var.env}"
  alarm_actions     = local.alarm_actions
}
