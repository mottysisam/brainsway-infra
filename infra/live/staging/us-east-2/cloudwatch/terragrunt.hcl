include "root" { path = find_in_parent_folders() }
terraform { source = "../../../../modules/cloudwatch" }
inputs = {
  environment = "staging"
  log_groups = {
    "/aws/lambda/staging-functions" = {
      retention_days = 30
      tags = {
        Purpose     = "Lambda function logs for staging environment"
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