include "root" { path = find_in_parent_folders() }
terraform { source = "../../../../modules/cloudwatch" }
inputs = {
  environment = "dev"
  log_groups = {
    "/aws/lambda/dev-functions" = {
      retention_days = 14
      tags = {
        Purpose     = "Lambda function logs for dev environment"
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