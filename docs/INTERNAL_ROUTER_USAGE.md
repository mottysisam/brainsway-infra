# Internal Lambda Router Usage Guide

## Overview

The internal router provides secure Lambda-to-Lambda communication via API Gateway v2 with IAM authentication.

## Route Pattern

```
ANY /lambda/function/{function_name}
```

## Authentication

- **Method**: AWS IAM (SigV4)
- **Required Permission**: `execute-api:Invoke` on the internal route
- **Resource ARN**: `arn:aws:execute-api:us-east-2:ACCOUNT:API_ID/STAGE/lambda/function/*`

## Available Functions (Dev Environment)

| Short Name | Target Lambda Function | Description |
|------------|------------------------|-------------|
| `sync_clock` | `sync_clock` | Clock synchronization service |
| `generatePresignedUrl` | `generatePresignedUrl` | S3 presigned URL generator |
| `presignedUrlForS3Upload` | `presignedUrlForS3Upload` | S3 upload URL generator |
| `insert_ppu_data` | `insert-ppu-data-dev-insert_ppu` | PPU data insertion service |
| `softwareUpdateHandler` | `softwareUpdateHandler` | Software update handler |

## Usage Examples

### Using AWS CLI (with SigV4)

```bash
# Call sync_clock function
aws apigatewayv2 invoke \
  --api-id YOUR_API_ID \
  --stage v1 \
  --resource-path "/lambda/function/sync_clock" \
  --http-method GET \
  /tmp/response.json

# Call with POST data
aws apigatewayv2 invoke \
  --api-id YOUR_API_ID \
  --stage v1 \
  --resource-path "/lambda/function/insert_ppu_data" \
  --http-method POST \
  --body '{"data": "example"}' \
  /tmp/response.json
```

### Using curl (with aws-sigv4)

```bash
# GET request to sync_clock
curl -X GET https://api.dev.brainsway.cloud/lambda/function/sync_clock \
  --aws-sigv4 "aws:amz:us-east-2:execute-api" \
  --user "$AWS_ACCESS_KEY_ID:$AWS_SECRET_ACCESS_KEY"

# POST request with data
curl -X POST https://api.dev.brainsway.cloud/lambda/function/insert_ppu_data \
  --aws-sigv4 "aws:amz:us-east-2:execute-api" \
  --user "$AWS_ACCESS_KEY_ID:$AWS_SECRET_ACCESS_KEY" \
  -H "Content-Type: application/json" \
  -d '{"data": "example"}'
```

### Using AWS SDK (Python)

```python
import boto3
import json
from botocore.auth import SigV4Auth
from botocore.awsrequest import AWSRequest
import requests

def call_internal_function(function_name, method="GET", data=None):
    # Create AWS session
    session = boto3.Session()
    credentials = session.get_credentials()
    
    # Prepare request
    url = f"https://api.dev.brainsway.cloud/lambda/function/{function_name}"
    headers = {'Content-Type': 'application/json'} if data else {}
    body = json.dumps(data) if data else None
    
    # Sign request with SigV4
    request = AWSRequest(method=method, url=url, data=body, headers=headers)
    SigV4Auth(credentials, "execute-api", "us-east-2").add_auth(request)
    
    # Make request
    response = requests.request(
        method=method,
        url=url,
        headers=dict(request.headers),
        data=body
    )
    
    return response.json()

# Example usage
result = call_internal_function("sync_clock")
print(result)
```

### Using AWS SDK (Node.js)

```javascript
const AWS = require('aws-sdk');
const axios = require('axios');
const aws4 = require('aws4');

async function callInternalFunction(functionName, method = 'GET', data = null) {
  const options = {
    method,
    url: `https://api.dev.brainsway.cloud/lambda/function/${functionName}`,
    headers: {
      'Content-Type': 'application/json'
    },
    data: data ? JSON.stringify(data) : undefined
  };
  
  // Sign with AWS credentials
  aws4.sign(options, {
    accessKeyId: process.env.AWS_ACCESS_KEY_ID,
    secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY,
    sessionToken: process.env.AWS_SESSION_TOKEN,
    region: 'us-east-2',
    service: 'execute-api'
  });
  
  const response = await axios(options);
  return response.data;
}

// Example usage
callInternalFunction('sync_clock')
  .then(result => console.log(result))
  .catch(error => console.error(error));
```

## Response Format

The internal router returns responses in standard API Gateway Lambda proxy format:

```json
{
  "statusCode": 200,
  "headers": {
    "Content-Type": "application/json",
    "X-Request-ID": "uuid-here",
    "X-Function-Name": "sync_clock",
    "X-Duration-MS": "150"
  },
  "body": "{\"time_est\": \"2025-08-12T17:58:53.027568-04:00\", \"timestamp_unix\": 1755035933}"
}
```

## Error Responses

### 404 - Unknown Function
```json
{
  "statusCode": 404,
  "headers": {"Content-Type": "application/json"},
  "body": "{\"error\": \"unknown_function\", \"function_name\": \"invalid_name\", \"available_functions\": [\"sync_clock\", \"generatePresignedUrl\"]}"
}
```

### 405 - Method Not Allowed
```json
{
  "statusCode": 405,
  "headers": {"Content-Type": "application/json"},
  "body": "{\"error\": \"method_not_allowed\", \"method\": \"PATCH\"}"
}
```

### 502 - Lambda Invocation Failed
```json
{
  "statusCode": 502,
  "headers": {"Content-Type": "application/json"},
  "body": "{\"error\": \"lambda_invoke_failed\", \"function_name\": \"sync_clock\", \"message\": \"Target Lambda invocation failed\"}"
}
```

## IAM Policy Example

Attach this policy to roles/users that need to call internal functions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowInternalLambdaRouting",
      "Effect": "Allow",
      "Action": ["execute-api:Invoke"],
      "Resource": ["arn:aws:execute-api:us-east-2:824357028182:*/*/lambda/function/*"],
      "Condition": {
        "StringEquals": {
          "execute-api:StageName": ["v1"]
        }
      }
    }
  ]
}
```

## Security Features

1. **IAM Authentication**: All requests must be signed with valid AWS credentials
2. **Function Allowlist**: Router can only invoke explicitly allowed Lambda ARNs
3. **Request Logging**: All requests are logged with request ID, function name, and timing
4. **Error Handling**: Detailed error responses with proper status codes
5. **Request Tracking**: X-Request-ID header for tracing requests end-to-end

## Monitoring

- **CloudWatch Logs**: `/aws/lambda/brainsway-internal-router-dev`
- **Metrics**: Function invocation count, duration, error rates
- **Alarms**: High error rates and duration thresholds
- **X-Ray Tracing**: End-to-end request tracing (if enabled)

## Adding New Functions

To add a new function to the router:

1. Update the `function_map` in `terragrunt.hcl`
2. Add the Lambda ARN to `allowed_lambda_arns`
3. Deploy the changes with `terragrunt apply`

Example:
```hcl
function_map = {
  # ... existing functions ...
  "new_function" = "arn:aws:lambda:us-east-2:824357028182:function:my-new-function"
}

allowed_lambda_arns = [
  # ... existing ARNs ...
  "arn:aws:lambda:us-east-2:824357028182:function:my-new-function"
]
```