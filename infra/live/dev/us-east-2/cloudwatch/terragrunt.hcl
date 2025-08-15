include "root" { path = find_in_parent_folders() }
terraform { source = "../../../../modules/cloudwatch" }
inputs = {
  environment = "dev"
  log_groups = {
    # Individual Lambda function log groups
    "/aws/lambda/sync-clock" = {
      retention_days = 14
      tags = {
        Purpose     = "Sync clock Lambda function logs"
        Environment = "dev"
        Function    = "sync-clock"
      }
    }
    "/aws/lambda/generate-presigned-url" = {
      retention_days = 14
      tags = {
        Purpose     = "Generate presigned URL Lambda function logs"
        Environment = "dev"
        Function    = "generate-presigned-url"
      }
    }
    "/aws/lambda/presigned-url-s3-upload" = {
      retention_days = 14
      tags = {
        Purpose     = "Presigned URL S3 upload Lambda function logs"
        Environment = "dev"
        Function    = "presigned-url-s3-upload"
      }
    }
    "/aws/lambda/software-update-handler" = {
      retention_days = 14
      tags = {
        Purpose     = "Software update handler Lambda function logs"
        Environment = "dev"
        Function    = "software-update-handler"
      }
    }
    "/aws/lambda/insert-ppu-data" = {
      retention_days = 14
      tags = {
        Purpose     = "Insert PPU data Lambda function logs"
        Environment = "dev"
        Function    = "insert-ppu-data"
      }
    }
    "/aws/lambda/lambda-test-runner" = {
      retention_days = 7
      tags = {
        Purpose     = "Lambda test runner function logs"
        Environment = "dev"
        Function    = "lambda-test-runner"
      }
    }
    "/aws/lambda/internal-router" = {
      retention_days = 14
      tags = {
        Purpose     = "Internal router Lambda function logs"
        Environment = "dev"
        Function    = "internal-router"
      }
    }
    # Legacy group for compatibility
    "/aws/lambda/dev-functions" = {
      retention_days = 14
      tags = {
        Purpose     = "Legacy Lambda function logs for dev environment"
        Environment = "dev"
      }
    }
    "/aws/apigateway/dev-apis" = {
      retention_days = 14
      tags = {
        Purpose     = "API Gateway execution logs for dev environment" 
        Environment = "dev"
      }
    }
    "/brainsway/infrastructure/dev" = {
      retention_days = 30
      tags = {
        Purpose     = "Infrastructure deployment and application logs for dev"
        Environment = "dev"
      }
    }
    "/brainsway/ec2/dev" = {
      retention_days = 7
      tags = {
        Purpose     = "EC2 instance logs for dev environment"
        Environment = "dev"
      }
    }
  }
}