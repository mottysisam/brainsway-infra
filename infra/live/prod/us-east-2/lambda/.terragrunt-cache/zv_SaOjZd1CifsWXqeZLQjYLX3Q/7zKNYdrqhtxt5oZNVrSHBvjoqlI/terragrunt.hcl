include "root" { path = find_in_parent_folders() }
terraform { source = "../../../../modules/lambda" }
inputs = {
  "functions": {
    "insert-ppu-data-dev-insert_ppu": {
      "role": "arn:aws:iam::154948530138:role/lambda-vpc-role",
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
      "environment": null
    },
    "generatePresignedUrl": {
      "role": "arn:aws:iam::154948530138:role/lambda_s3_execution",
      "handler": "lambda_function.lambda_handler",
      "runtime": "python3.6",
      "timeout": 10,
      "memory_size": 128,
      "architectures": [
        "x86_64"
      ],
      "layers": null,
      "environment": null
    },
    "presignedUrlForS3Upload": {
      "role": "arn:aws:iam::154948530138:role/lambda_s3_execution",
      "handler": "lambda_function.lambda_handler",
      "runtime": "python3.6",
      "timeout": 10,
      "memory_size": 128,
      "architectures": [
        "x86_64"
      ],
      "layers": null,
      "environment": null
    },
    "sync_clock": {
      "role": "arn:aws:iam::154948530138:role/lambda-vpc-role",
      "handler": "lambda_function.lambda_handler",
      "runtime": "python3.12",
      "timeout": 3,
      "memory_size": 128,
      "architectures": [
        "x86_64"
      ],
      "layers": null,
      "environment": null
    },
    "softwareUpdateHandler": {
      "role": "arn:aws:iam::154948530138:role/sf_update_lambda_role",
      "handler": "lambda_function.lambda_handler",
      "runtime": "python3.6",
      "timeout": 10,
      "memory_size": 128,
      "architectures": [
        "x86_64"
      ],
      "layers": null,
      "environment": null
    }
  },
  "function_urls": [],
  "aliases": [
    "insert-ppu-data-dev-insert_ppu:latest"
  ]
}
