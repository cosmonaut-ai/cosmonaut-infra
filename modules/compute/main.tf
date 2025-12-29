# SQS queues for async processing
resource "aws_sqs_queue" "fast" {
  name                       = "cosmonaut-${var.env}-fast"
  visibility_timeout_seconds = 60
}

resource "aws_sqs_queue" "slow" {
  name                       = "cosmonaut-${var.env}-slow"
  visibility_timeout_seconds = 900
}

# Event source mappings to route SQS messages to the shared Lambda worker handler
resource "aws_lambda_event_source_mapping" "fast_queue" {
  event_source_arn = aws_sqs_queue.fast.arn
  function_name    = var.fast_worker_lambda_arn
  batch_size       = 10
}

resource "aws_lambda_event_source_mapping" "slow_queue" {
  event_source_arn = aws_sqs_queue.slow.arn
  function_name    = var.slow_worker_lambda_arn
  batch_size       = 10

  scaling_config {
    maximum_concurrency = 50
  }
}
