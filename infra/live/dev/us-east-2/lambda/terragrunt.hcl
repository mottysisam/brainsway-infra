include "root" { path = find_in_parent_folders() }
terraform { source = "../../../../modules/lambda" }
inputs = {
  "functions": {
    "insert-ppu-data-dev": {
      "role": "arn:aws:iam::824357028182:role/lambda-vpc-role",
      "handler": "insertPPUData.handler",
      "runtime": "python3.9",
      "timeout": 6,
      "memory_size": 1024,
      "architectures": [
        "x86_64"
      ],
      "layers": [
        "arn:aws:lambda:us-east-2:770693421928:layer:Klayers-p39-psycopg2-binary:1"
      ],
      "environment": {
        "ENVIRONMENT": "dev",
        "DYNAMODB_TABLE": "event_log-dev"
      },
      "filename": "placeholder.zip",
      "tags": {
        "Environment": "dev"
      }
    },
    "generatePresignedUrl-dev": {
      "role": "arn:aws:iam::824357028182:role/lambda_s3_execution",
      "handler": "lambda_function.lambda_handler",
      "runtime": "python3.6",
      "timeout": 10,
      "memory_size": 128,
      "architectures": [
        "x86_64"
      ],
      "layers": null,
      "environment": {
        "ENVIRONMENT": "dev"
      },
      "filename": "placeholder.zip",
      "tags": {
        "Environment": "dev"
      }
    },
    "presignedUrlForS3Upload-dev": {
      "role": "arn:aws:iam::824357028182:role/lambda_s3_execution",
      "handler": "lambda_function.lambda_handler",
      "runtime": "python3.6",
      "timeout": 10,
      "memory_size": 128,
      "architectures": [
        "x86_64"
      ],
      "layers": null,
      "environment": {
        "ENVIRONMENT": "dev"
      },
      "filename": "placeholder.zip",
      "tags": {
        "Environment": "dev"
      }
    },
    "sync_clock-dev": {
      "role": "arn:aws:iam::824357028182:role/lambda-vpc-role",
      "handler": "lambda_function.lambda_handler",
      "runtime": "python3.12",
      "timeout": 3,
      "memory_size": 128,
      "architectures": [
        "x86_64"
      ],
      "layers": null,
      "environment": {
        "ENVIRONMENT": "dev"
      },
      "filename": "placeholder.zip",
      "tags": {
        "Environment": "dev"
      }
    },
    "softwareUpdateHandler-dev": {
      "role": "arn:aws:iam::824357028182:role/sf_update_lambda_role",
      "handler": "lambda_function.lambda_handler",
      "runtime": "python3.6",
      "timeout": 10,
      "memory_size": 128,
      "architectures": [
        "x86_64"
      ],
      "layers": null,
      "environment": {
        "ENVIRONMENT": "dev",
        "DYNAMODB_TABLE": "sw_update-dev"
      },
      "filename": "placeholder.zip",
      "tags": {
        "Environment": "dev"
      }
    }
  },
  "function_urls": [],
  "aliases": [
    "insert-ppu-data-dev:latest"
  ]
}
