include "root" { path = find_in_parent_folders() }
terraform { source = "../../../../modules/lambda" }
inputs = {
  "functions": {
    "insert-ppu-data-staging": {
      "role": "arn:aws:iam::574210586915:role/lambda-vpc-role",
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
        "ENVIRONMENT": "staging",
        "DYNAMODB_TABLE": "event_log-staging"
      },
      "filename": "placeholder.zip",
      "tags": {
        "Environment": "staging"
      }
    },
    "generatePresignedUrl-staging": {
      "role": "arn:aws:iam::574210586915:role/lambda_s3_execution",
      "handler": "lambda_function.lambda_handler",
      "runtime": "python3.9",
      "timeout": 10,
      "memory_size": 128,
      "architectures": [
        "x86_64"
      ],
      "layers": null,
      "environment": {
        "ENVIRONMENT": "staging"
      },
      "filename": "placeholder.zip",
      "tags": {
        "Environment": "staging"
      }
    },
    "presignedUrlForS3Upload-staging": {
      "role": "arn:aws:iam::574210586915:role/lambda_s3_execution",
      "handler": "lambda_function.lambda_handler",
      "runtime": "python3.9",
      "timeout": 10,
      "memory_size": 128,
      "architectures": [
        "x86_64"
      ],
      "layers": null,
      "environment": {
        "ENVIRONMENT": "staging"
      },
      "filename": "placeholder.zip",
      "tags": {
        "Environment": "staging"
      }
    },
    "sync_clock-staging": {
      "role": "arn:aws:iam::574210586915:role/lambda-vpc-role",
      "handler": "lambda_function.lambda_handler",
      "runtime": "python3.12",
      "timeout": 3,
      "memory_size": 128,
      "architectures": [
        "x86_64"
      ],
      "layers": null,
      "environment": {
        "ENVIRONMENT": "staging"
      },
      "filename": "placeholder.zip",
      "tags": {
        "Environment": "staging"
      }
    },
    "softwareUpdateHandler-staging": {
      "role": "arn:aws:iam::574210586915:role/sf_update_lambda_role",
      "handler": "lambda_function.lambda_handler",
      "runtime": "python3.9",
      "timeout": 10,
      "memory_size": 128,
      "architectures": [
        "x86_64"
      ],
      "layers": null,
      "environment": {
        "ENVIRONMENT": "staging",
        "DYNAMODB_TABLE": "sw_update-staging"
      },
      "filename": "placeholder.zip",
      "tags": {
        "Environment": "staging"
      }
    }
  },
  "function_urls": [],
  "aliases": [
    "insert-ppu-data-staging:latest"
  ]
}
