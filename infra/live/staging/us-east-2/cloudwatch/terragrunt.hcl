include "root" { path = find_in_parent_folders() }
terraform { source = "../../../../modules/cloudwatch" }
inputs = {
  environment = "staging"
  log_groups = {
    # Individual Lambda function log groups
    "/aws/lambda/sync-clock" = {
      retention_days = 30
      tags = {
        Purpose     = "Sync clock Lambda function logs"
        Environment = "staging"
        Function    = "sync-clock"
      }
    }
    "/aws/lambda/generate-presigned-url" = {
      retention_days = 30
      tags = {
        Purpose     = "Generate presigned URL Lambda function logs"
        Environment = "staging"
        Function    = "generate-presigned-url"
      }
    }
    "/aws/lambda/presigned-url-s3-upload" = {
      retention_days = 30
      tags = {
        Purpose     = "Presigned URL S3 upload Lambda function logs"
        Environment = "staging"
        Function    = "presigned-url-s3-upload"
      }
    }
    "/aws/lambda/software-update-handler" = {
      retention_days = 30
      tags = {
        Purpose     = "Software update handler Lambda function logs"
        Environment = "staging"
        Function    = "software-update-handler"
      }
    }
    "/aws/lambda/insert-ppu-data" = {
      retention_days = 30
      tags = {
        Purpose     = "Insert PPU data Lambda function logs"
        Environment = "staging"
        Function    = "insert-ppu-data"
      }
    }
    "/aws/lambda/lambda-test-runner" = {
      retention_days = 14
      tags = {
        Purpose     = "Lambda test runner function logs"
        Environment = "staging"
        Function    = "lambda-test-runner"
      }
    }
    "/aws/lambda/internal-router" = {
      retention_days = 30
      tags = {
        Purpose     = "Internal router Lambda function logs"
        Environment = "staging"
        Function    = "internal-router"
      }
    }
    # Legacy group for compatibility
    "/aws/lambda/staging-functions" = {
      retention_days = 30
      tags = {
        Purpose     = "Legacy Lambda function logs for staging environment"
        Environment = "staging"
      }
    }
    "/aws/apigateway/staging-apis" = {
      retention_days = 30
      tags = {
        Purpose     = "API Gateway execution logs for staging environment"
        Environment = "staging"
      }
    }
    "/brainsway/infrastructure/staging" = {
      retention_days = 60
      tags = {
        Purpose     = "Infrastructure deployment and application logs for staging"
        Environment = "staging"
      }
    }
    "/brainsway/ec2/staging" = {
      retention_days = 14
      tags = {
        Purpose     = "EC2 instance logs for staging environment"
        Environment = "staging"
      }
    }
    "/brainsway/rds/staging" = {
      retention_days = 30
      tags = {
        Purpose     = "RDS and Aurora database logs for staging"
        Environment = "staging"
      }
    }
  }
}