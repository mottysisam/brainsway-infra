terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# Lambda VPC Role
resource "aws_iam_role" "lambda_vpc_role" {
  count = var.create_lambda_vpc_role ? 1 : 0
  name  = "lambda-vpc-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "lambda_vpc_role_policy" {
  count      = var.create_lambda_vpc_role ? 1 : 0
  role       = aws_iam_role.lambda_vpc_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Lambda S3 Execution Role
resource "aws_iam_role" "lambda_s3_execution" {
  count = var.create_lambda_s3_execution ? 1 : 0
  name  = "lambda_s3_execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "lambda_s3_execution_basic" {
  count      = var.create_lambda_s3_execution ? 1 : 0
  role       = aws_iam_role.lambda_s3_execution[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_s3_execution_s3" {
  count      = var.create_lambda_s3_execution ? 1 : 0
  role       = aws_iam_role.lambda_s3_execution[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

# Software Update Lambda Role
resource "aws_iam_role" "sf_update_lambda_role" {
  count = var.create_sf_update_lambda_role ? 1 : 0
  name  = "sf_update_lambda_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "sf_update_lambda_role_basic" {
  count      = var.create_sf_update_lambda_role ? 1 : 0
  role       = aws_iam_role.sf_update_lambda_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "sf_update_lambda_role_sns" {
  count      = var.create_sf_update_lambda_role ? 1 : 0
  role       = aws_iam_role.sf_update_lambda_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSNSFullAccess"
}

resource "aws_iam_role_policy_attachment" "sf_update_lambda_role_dynamodb" {
  count      = var.create_sf_update_lambda_role ? 1 : 0
  role       = aws_iam_role.sf_update_lambda_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}