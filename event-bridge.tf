provider "aws" {
  region = "us-east-1"  # Change this to your desired region
}

data "archive_file" "lambda" {
  type        = "zip"
  source_file = "lambda_function.py"
  output_path = "lambda_function_payload.zip"
}

# aws_lambda_function.event_target:
resource "aws_lambda_function" "event_target" {
    filename                       = "lambda_function_payload.zip"
    function_name                  = "metadata-extraction"
    handler                        = "lambda_function.lambda_handler"
    layers                         = []
    memory_size                    = 128
    package_type                   = "Zip"
    reserved_concurrent_executions = -1
    role                           = aws_iam_role.basic-lambda-execution-role.arn
    runtime                        = "python3.11"
    skip_destroy                   = false
    source_code_hash               = data.archive_file.lambda.output_base64sha256
    tags                           = {}
    tags_all                       = {}
    timeout                        = 3

    ephemeral_storage {
        size = 512
    }

    tracing_config {
        mode = "PassThrough"
    }
}

data "aws_iam_policy_document" "lambda_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "basic-lambda-execution-role" {
  assume_role_policy    = data.aws_iam_policy_document.lambda_assume_role_policy.json
  description           = null
  force_detach_policies = false
  max_session_duration  = 3600
  name                  = "basic-lambda-execution-role"
  name_prefix           = null
  permissions_boundary  = null
  tags                  = {}
  tags_all              = {}
}

resource "aws_iam_role_policy_attachment" "lambda_execution_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.basic-lambda-execution-role.name
}

resource "aws_lambda_permission" "allow_eventbridge_invoke" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.event_target.function_name
  principal     = "events.amazonaws.com"

  source_arn = aws_cloudwatch_event_rule.s3_bucket_creation_rule.arn
}

resource "aws_cloudwatch_event_rule" "s3_bucket_creation_rule" {
  name = "s3_bucket_creation_rule"

  event_pattern = <<EOF
{
  "source": ["aws.s3"],
  "detail": {
    "eventName": ["CreateBucket"]
  }
}
EOF
}

resource "aws_cloudwatch_event_target" "invoke_lambda" {
  rule      = aws_cloudwatch_event_rule.s3_bucket_creation_rule.name
  target_id = "invoke_lambda"

  arn = aws_lambda_function.event_target.arn
}

resource "aws_iam_policy" "s3_metadata_policy" {
  name        = "s3-metadata-policy"
  description = "IAM policy to allow Lambda to retrieve S3 bucket metadata"

  # Policy document that grants necessary permissions
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action   = [
          "s3:GetBucketAcl",
          "s3:GetBucketVersioning",
          "s3:GetBucketLogging",
          "s3:GetBucketWebsite",
          "Abra:kadabra"
          # Add more S3 actions as needed
        ],
        Effect   = "Allow",
        Resource = "arn:aws:s3:::*" # Replace with your S3 bucket ARN or wildcard if applicable
      },
      # Add more statements for additional permissions if needed
    ],
  })
}

resource "aws_iam_role_policy_attachment" "s3_metadata_policy_attachment" {
  policy_arn = aws_iam_policy.s3_metadata_policy.arn
  role       = aws_iam_role.basic-lambda-execution-role.name
}
