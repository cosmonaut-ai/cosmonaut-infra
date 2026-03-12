resource "aws_dynamodb_table" "main" {
  name         = "cosmonaut-${var.env}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "PK"
  range_key    = "SK"

  attribute {
    name = "PK"
    type = "S"
  }

  attribute {
    name = "SK"
    type = "S"
  }

  attribute {
    name = "GSI1PK"
    type = "S"
  }

  attribute {
    name = "GSI1SK"
    type = "S"
  }

  attribute {
    name = "GSI2PK"
    type = "S"
  }

  attribute {
    name = "GSI2SK"
    type = "S"
  }

  global_secondary_index {
    name            = "GSI1"
    hash_key        = "GSI1PK"
    range_key       = "GSI1SK"
    projection_type = "ALL"
  }

  global_secondary_index {
    name               = "GSI2"
    hash_key           = "GSI2PK"
    range_key          = "GSI2SK"
    projection_type    = "INCLUDE"
    non_key_attributes = ["node_title", "node_parent_id", "node_choices", "node_id", "node_generation_status"]
  }

  ttl {
    attribute_name = "expiration"
    enabled        = true
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = {
    Environment = var.env
    Project     = "cosmonaut"
  }
}

