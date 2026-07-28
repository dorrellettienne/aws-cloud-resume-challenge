locals {
  name_prefix = "${var.project_name}-${var.environment}"
  common_tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = var.project_name
  }
}

data "archive_file" "visitor_counter" {
  type        = "zip"
  source_file = "${path.module}/lambda/func.py"
  output_path = "${path.module}/lambda/func.zip"
}

data "aws_cloudfront_cache_policy" "caching_optimized" {
  name = "Managed-CachingOptimized"
}

resource "aws_dynamodb_table" "visitor_counter" {
  name         = "${local.name_prefix}-visitor-counter"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }
}

resource "aws_iam_role" "lambda" {
  name = "${local.name_prefix}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "counter_table" {
  name = "${local.name_prefix}-counter-table"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action   = ["dynamodb:UpdateItem"]
      Effect   = "Allow"
      Resource = aws_dynamodb_table.visitor_counter.arn
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "visitor_counter" {
  filename         = data.archive_file.visitor_counter.output_path
  source_code_hash = data.archive_file.visitor_counter.output_base64sha256
  function_name    = "${local.name_prefix}-visitor-counter"
  role             = aws_iam_role.lambda.arn
  handler          = "func.lambda_handler"
  runtime          = "python3.12"
  memory_size      = 128
  timeout          = 5

  reserved_concurrent_executions = 5

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.visitor_counter.name
    }
  }

  depends_on = [
    aws_iam_role_policy.counter_table,
    aws_iam_role_policy_attachment.lambda_logs,
  ]
}

resource "aws_lambda_function_url" "visitor_counter" {
  function_name      = aws_lambda_function.visitor_counter.function_name
  authorization_type = "NONE"

  cors {
    allow_credentials = false
    allow_headers     = ["content-type"]
    allow_methods     = ["GET"]
    allow_origins     = ["*"]
    max_age           = 86400
  }
}

resource "aws_s3_bucket" "resume" {
  bucket_prefix = "${local.name_prefix}-site-"
}

resource "aws_s3_bucket_public_access_block" "resume" {
  bucket = aws_s3_bucket.resume.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "resume" {
  bucket = aws_s3_bucket.resume.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "resume" {
  bucket = aws_s3_bucket.resume.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "resume" {
  bucket = aws_s3_bucket.resume.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_cloudfront_origin_access_control" "resume" {
  name                              = "${local.name_prefix}-oac"
  description                       = "Restricts the resume bucket to CloudFront"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_response_headers_policy" "security" {
  name = "${local.name_prefix}-security-headers"

  security_headers_config {
    content_type_options {
      override = true
    }

    frame_options {
      frame_option = "SAMEORIGIN"
      override     = true
    }

    referrer_policy {
      referrer_policy = "strict-origin-when-cross-origin"
      override        = true
    }

    strict_transport_security {
      access_control_max_age_sec = 63072000
      include_subdomains         = true
      override                   = true
      preload                    = true
    }
  }
}

resource "aws_cloudfront_distribution" "resume" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  price_class         = "PriceClass_100"

  origin {
    domain_name              = aws_s3_bucket.resume.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.resume.id
    origin_id                = "resume-s3-origin"
  }

  default_cache_behavior {
    allowed_methods            = ["GET", "HEAD", "OPTIONS"]
    cached_methods             = ["GET", "HEAD"]
    cache_policy_id            = data.aws_cloudfront_cache_policy.caching_optimized.id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.security.id
    target_origin_id           = "resume-s3-origin"
    viewer_protocol_policy     = "redirect-to-https"
    compress                   = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

data "aws_iam_policy_document" "resume_bucket" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.resume.arn}/*"]

    principals {
      identifiers = ["cloudfront.amazonaws.com"]
      type        = "Service"
    }

    condition {
      test     = "StringEquals"
      values   = [aws_cloudfront_distribution.resume.arn]
      variable = "AWS:SourceArn"
    }
  }
}

resource "aws_s3_bucket_policy" "resume" {
  bucket = aws_s3_bucket.resume.id
  policy = data.aws_iam_policy_document.resume_bucket.json

  depends_on = [aws_s3_bucket_public_access_block.resume]
}
