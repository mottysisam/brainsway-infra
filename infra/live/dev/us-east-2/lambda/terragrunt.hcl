include "root" { path = find_in_parent_folders() }
terraform { source = "../../../../modules/lambda" }

locals {
  env_vars    = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  environment = local.env_vars.locals.env
  aws_account = local.env_vars.locals.aws_account
  aws_region  = local.env_vars.locals.aws_region
}

inputs = {
  functions = {
    # Internal Router - Enhanced with parameter flattening
    "internal-router" = {
      role          = "arn:aws:iam::${local.aws_account}:role/lambda-vpc-role"
      handler       = "src/index.handler"
      runtime       = "nodejs20.x"
      timeout       = 30
      memory_size   = 256
      architectures = ["x86_64"]
      layers        = null
      environment = {
        FUNCTION_NAME            = "internal-router"
        CACHE_TTL_MS             = "300000"
        ENABLE_DIRECT_INVOCATION = "true"
        ENVIRONMENT              = local.environment
        AWS_ACCOUNT_ID           = local.aws_account
        FUNCTION_MAP = jsonencode({
          "generate-presigned-url"  = "arn:aws:lambda:${local.aws_region}:${local.aws_account}:function:generate-presigned-url"
          "insert-ppu-data"         = "arn:aws:lambda:${local.aws_region}:${local.aws_account}:function:insert-ppu-data"
          "presigned-url-s3-upload" = "arn:aws:lambda:${local.aws_region}:${local.aws_account}:function:presigned-url-s3-upload"
          "software-update-handler" = "arn:aws:lambda:${local.aws_region}:${local.aws_account}:function:software-update-handler"
          "sync-clock"              = "arn:aws:lambda:${local.aws_region}:${local.aws_account}:function:sync-clock"
          # Legacy names for backward compatibility
          "generatePresignedUrl-v-1-8"     = "arn:aws:lambda:${local.aws_region}:${local.aws_account}:function:generate-presigned-url"
          "insert-ppu-data-dev-insert_ppu" = "arn:aws:lambda:${local.aws_region}:${local.aws_account}:function:insert-ppu-data"
        })
        LOG_LEVEL = "INFO"
      }
      tags = {
        Environment = local.environment
        Function    = "internal-router"
      }
    }

    # PPU Data Insert - Enhanced with error handling and body parsing
    "insert-ppu-data" = {
      role          = "arn:aws:iam::${local.aws_account}:role/lambda-vpc-role"
      handler       = "src/insertPPUData.handler"
      runtime       = "python3.9"
      timeout       = 6
      memory_size   = 1024
      architectures = ["x86_64"]
      layers = [
        "arn:aws:lambda:${local.aws_region}:770693421928:layer:Klayers-p39-psycopg2-binary:1"
      ]
      vpc_config = {
        subnet_ids = [
          "subnet-bc5f56d4",
          "subnet-7b430401",
          "subnet-e577d8a9"
        ]
        security_group_ids = ["sg-0cb4d7360eb9f9b4a"] # Dev environment security group
      }
      environment = {
        ENVIRONMENT    = local.environment
        DB_ENDPOINT    = "bwppudb.cluster-cibvsppk6iez.us-east-2.rds.amazonaws.com" # Dev RDS endpoint
        DB_PORT        = "5432"
        DB_USER        = "brainsway"
        DB_PASSWORD    = "brainswaypwd"
        DB_NAME        = "bwppudb"
        DYNAMODB_TABLE = "event_log-dev" # Dev DynamoDB table
      }
      tags = {
        Environment = local.environment
        Function    = "insert-ppu-data"
      }
    }

    # Generate Presigned URL - S3 software update downloads
    "generate-presigned-url" = {
      role          = "arn:aws:iam::${local.aws_account}:role/lambda_s3_execution"
      handler       = "src/lambda_function.lambda_handler"
      runtime       = "python3.9"
      timeout       = 10
      memory_size   = 128
      architectures = ["x86_64"]
      layers        = null
      environment = {
        ENVIRONMENT = local.environment
      }
      tags = {
        Environment = local.environment
        Function    = "generate-presigned-url"
      }
    }

    # Presigned URL for S3 Upload
    "presigned-url-s3-upload" = {
      role          = "arn:aws:iam::${local.aws_account}:role/lambda_s3_execution"
      handler       = "src/lambda_function.lambda_handler"
      runtime       = "python3.9"
      timeout       = 10
      memory_size   = 128
      architectures = ["x86_64"]
      layers        = null
      environment = {
        ENVIRONMENT = local.environment
      }
      tags = {
        Environment = local.environment
        Function    = "presigned-url-s3-upload"
      }
    }

    # Software Update Handler
    "software-update-handler" = {
      role          = "arn:aws:iam::${local.aws_account}:role/sf_update_lambda_role"
      handler       = "src/lambda_function.lambda_handler"
      runtime       = "python3.9"
      timeout       = 10
      memory_size   = 128
      architectures = ["x86_64"]
      layers        = null
      environment = {
        ENVIRONMENT    = local.environment
        DYNAMODB_TABLE = "sw_update-dev" # Dev DynamoDB table
        SNS_TOPIC_ARN  = "arn:aws:sns:${local.aws_region}:${local.aws_account}:software-update-alerts"
      }
      tags = {
        Environment = local.environment
        Function    = "software-update-handler"
      }
    }

    # Sync Clock - Database time synchronization
    "sync-clock" = {
      role          = "arn:aws:iam::${local.aws_account}:role/lambda-vpc-role"
      handler       = "src/lambda_function.lambda_handler"
      runtime       = "python3.12"
      timeout       = 3
      memory_size   = 128
      architectures = ["x86_64"]
      layers        = null
      vpc_config = {
        subnet_ids = [
          "subnet-bc5f56d4",
          "subnet-7b430401",
          "subnet-e577d8a9"
        ]
        security_group_ids = ["sg-0cb4d7360eb9f9b4a"] # Dev environment security group
      }
      environment = {
        ENVIRONMENT = local.environment
      }
      tags = {
        Environment = local.environment
        Function    = "sync-clock"
      }
    }

    # Lambda Test Runner - API-accessible testing system
    "lambda-test-runner" = {
      role          = "arn:aws:iam::${local.aws_account}:role/lambda-test-runner-role"
      handler       = "src/lambda_function.lambda_handler"
      runtime       = "python3.9"
      timeout       = 300  # 5 minutes for comprehensive testing
      memory_size   = 1024 # High memory for pytest and report generation
      architectures = ["x86_64"]
      layers        = null

      # VPC config for database connectivity testing
      vpc_config = {
        subnet_ids = [
          "subnet-bc5f56d4",
          "subnet-7b430401",
          "subnet-e577d8a9"
        ]
        security_group_ids = ["sg-0cb4d7360eb9f9b4a"] # Dev environment security group
      }

      environment = {
        ENVIRONMENT        = local.environment
        AWS_DEFAULT_REGION = local.aws_region
        AWS_ACCOUNT_ID     = local.aws_account

        # Database configuration for testing
        DB_ENDPOINT = "bwppudb.cluster-cibvsppk6iez.us-east-2.rds.amazonaws.com" # Dev RDS endpoint
        DB_PORT     = "5432"
        DB_USER     = "brainsway"
        DB_PASSWORD = "brainswaypwd"
        DB_NAME     = "bwppudb"

        # DynamoDB configuration
        DYNAMODB_TABLE = "sw_update-dev" # Dev DynamoDB table

        # S3 bucket for test reports
        TEST_S3_BUCKET = "bw-lambda-test-reports-dev" # Dev-specific bucket

        # Test configuration
        LOG_LEVEL                     = "INFO"
        ENABLE_PERFORMANCE_MONITORING = "true"

        # Lambda functions to test (their ARNs)
        LAMBDA_FUNCTIONS = jsonencode({
          "insert-ppu-data"         = "arn:aws:lambda:${local.aws_region}:${local.aws_account}:function:insert-ppu-data"
          "generate-presigned-url"  = "arn:aws:lambda:${local.aws_region}:${local.aws_account}:function:generate-presigned-url"
          "presigned-url-s3-upload" = "arn:aws:lambda:${local.aws_region}:${local.aws_account}:function:presigned-url-s3-upload"
          "software-update-handler" = "arn:aws:lambda:${local.aws_region}:${local.aws_account}:function:software-update-handler"
          "sync-clock"              = "arn:aws:lambda:${local.aws_region}:${local.aws_account}:function:sync-clock"
          "internal-router"         = "arn:aws:lambda:${local.aws_region}:${local.aws_account}:function:internal-router"
        })
      }

      tags = {
        Environment = local.environment
        Function    = "lambda-test-runner"
        Purpose     = "API-accessible Lambda function testing system"
      }
    }
  }

  # Add function URLs for test runner API access
  function_urls = ["lambda-test-runner"]

  # Aliases for compatibility
  aliases = [
    "insert-ppu-data:latest"
  ]
}