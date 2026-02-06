# Define common environment variables for all Lambda functions
locals {
  lambda_env_vars = {
    # Queue URLs
    FAST_WORKER_QUEUE_URL = aws_sqs_queue.fast.id
    SLOW_WORKER_QUEUE_URL = aws_sqs_queue.slow.id

    # Database and storage
    DYNAMODB_TABLE_NAME = var.dynamodb_table_arn
    PINECONE_INDEX      = var.pinecone_index_name

    # Authentication
    COGNITO_USER_POOL_ID = var.cognito_user_pool_id
    COGNITO_CLIENT_ID    = var.cognito_user_pool_client_id
    MOCK_AUTH            = var.mock_auth

    # CloudFront
    CLOUDFRONT_KEY_PAIR_ID = var.cloudfront_key_pair_id

    # Google Cloud
    GOOGLE_APPLICATION_CREDENTIALS = "/var/task/client-config.json"

    # CORS
    CORS_ORIGINS = jsonencode(var.cors_allowed_origins)

    # Environment
    ENV = var.env

    # SSM Parameter paths (for runtime secret fetching)
    PINECONE_API_KEY_PARAM       = var.pinecone_key_name
    GEMINI_API_KEY_PARAM         = var.gemini_key_name
    GOOGLE_CLIENT_SECRET_PARAM   = var.google_client_secret_name
    CLOUDFRONT_PRIVATE_KEY_PARAM = var.cloudfront_private_key_name
  }
}

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
  function_name    = aws_lambda_function.worker_fast.function_name
  batch_size       = 10

  # Enable partial batch response so workers can return per-message failures
  function_response_types = ["ReportBatchItemFailures"]
}

resource "aws_lambda_event_source_mapping" "slow_queue" {
  event_source_arn = aws_sqs_queue.slow.arn
  function_name    = aws_lambda_function.worker_slow.function_name
  batch_size       = 10

  scaling_config {
    maximum_concurrency = 50
  }

  # Enable partial batch response so workers can return per-message failures
  function_response_types = ["ReportBatchItemFailures"]
}


# 1. API Lambda (The Entrypoint)
resource "aws_lambda_function" "api" {
  function_name = "cosmonaut-${var.env}-api"
  image_uri     = var.api_lambda_image_uri
  role          = aws_iam_role.lambda_exec.arn
  timeout       = 29 # API Gateway Limit
  memory_size   = var.api_memory_size
  package_type  = "Image"
  architectures = [var.lambda_architecture]

  image_config {
    entry_point = ["/bin/sh", "-c"]
    command     = ["python -m uvicorn app.main:app --host 0.0.0.0 --port 8080"]
  }

  environment {
    variables = local.lambda_env_vars
  }

  lifecycle {
    ignore_changes = [image_uri]
  }
}

# 2. Fast Worker (The Sprinter)
resource "aws_lambda_function" "worker_fast" {
  function_name = "cosmonaut-${var.env}-worker-fast"
  image_uri     = var.fast_worker_lambda_image_uri
  role          = aws_iam_role.lambda_exec.arn
  timeout       = 30 # Fail fast if text gen hangs
  memory_size   = var.worker_fast_memory_size

  package_type  = "Image"
  architectures = [var.lambda_architecture]

  image_config {
    command = ["app.worker.handler"] # <--- Worker Entrypoint
  }

  environment {
    variables = merge(local.lambda_env_vars, {
      AWS_LWA_INVOKE_MODE = "passthrough" # Bypass the aws-lambda-adapter for the worker
      GEMINI_TIMEOUT_S    = 900
    })
  }

  lifecycle {
    ignore_changes = [image_uri]
  }
}

# 3. Slow Worker (The Heavy Lifter)
resource "aws_lambda_function" "worker_slow" {
  function_name = "cosmonaut-${var.env}-worker-slow"
  image_uri     = var.slow_worker_lambda_image_uri
  role          = aws_iam_role.lambda_exec.arn
  timeout       = 900  # Allow 15 mins for heavy tasks
  memory_size   = 2048 # Give it more RAM

  package_type  = "Image"
  architectures = [var.lambda_architecture]

  image_config {
    command = ["app.worker.handler"] # <--- Same Entrypoint as Fast Worker
  }

  lifecycle {
    ignore_changes = [image_uri]
  }

  # Throttling is handled by the Event Source Mapping you already added!

  environment {
    variables = merge(local.lambda_env_vars, {
      AWS_LWA_INVOKE_MODE = "passthrough" # Bypass the aws-lambda-adapter for the worker
      GEMINI_TIMEOUT_S    = 900
      IMAGES_S3_BUCKET    = var.images_s3_bucket_name
      IMAGES_CDN_DOMAIN   = var.images_cdn_domain
    })
  }
}

# 4. Streaming API Lambda (The Streaming Entrypoint)
resource "aws_lambda_function" "api_streaming" {
  function_name = "cosmonaut-${var.env}-api-streaming"
  image_uri     = var.api_lambda_image_uri
  role          = aws_iam_role.lambda_exec.arn
  timeout       = 300
  memory_size   = var.api_memory_size
  package_type  = "Image"
  architectures = [var.lambda_architecture]

  image_config {
    entry_point = ["/bin/sh", "-c"]
    command     = ["python -m uvicorn app.main:app --host 0.0.0.0 --port 8080"]
  }

  environment {
    variables = merge(local.lambda_env_vars, {
      AWS_LWA_INVOKE_MODE = "RESPONSE_STREAM"
      GEMINI_TIMEOUT_S    = 900
    })
  }

  lifecycle {
    ignore_changes = [image_uri]
  }
}

# Create a public URL for the Streaming API Lambda (Required for CloudFront)
resource "aws_lambda_function_url" "api" {
  function_name      = aws_lambda_function.api_streaming.function_name
  authorization_type = "NONE" # Auth handled by FastAPI + WAF
  invoke_mode        = "RESPONSE_STREAM"


  cors {
    allow_origins  = var.cors_allowed_origins
    allow_headers  = ["content-type", "authorization"]
    expose_headers = ["content-type", "x-new-node-id"]
    max_age        = 300
  }
}
