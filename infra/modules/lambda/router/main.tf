data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# Default Lambda code (if source_code_path is not provided)
locals {
  default_python_code = <<-EOT
import json
import logging
import os
import time
import traceback

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

def handler(event, context):
    """
    AWS Lambda handler for API Gateway proxy integration
    
    This is a basic router that can be extended for specific API endpoints
    """
    
    try:
        # Log the incoming event (sanitized) - API Gateway v2 HTTP format
        event_log = {
            'httpMethod': event.get('requestContext', {}).get('http', {}).get('method', event.get('httpMethod')),
            'path': event.get('rawPath', event.get('path')),
            'resource': event.get('routeKey'),
            'stage': event.get('requestContext', {}).get('stage'),
            'requestId': event.get('requestContext', {}).get('requestId')
        }
        logger.info(f"Received event: {json.dumps(event_log)}")
        
        # Extract request information - API Gateway v2 HTTP format
        http_method = event.get('requestContext', {}).get('http', {}).get('method', event.get('httpMethod', 'GET'))
        path = event.get('rawPath', event.get('path', '/'))
        stage = event.get('requestContext', {}).get('stage', 'unknown')
        headers = event.get('headers', {})
        query_params = event.get('queryStringParameters') or {}
        path_params = event.get('pathParameters') or {}
        body = event.get('body', '')
        
        # Comprehensive routing logic
        if http_method == 'OPTIONS':
            # Handle CORS preflight requests
            return create_cors_response()
            
        elif path == '/health':
            return create_response(200, {
                'status': 'healthy',
                'timestamp': context.aws_request_id,
                'environment': os.environ.get('ENVIRONMENT', 'unknown'),
                'version': '1.0.0',
                'checks': {
                    'lambda': 'ok',
                    'timestamp': int(time.time()),
                    'uptime': 'available'
                }
            })
        
        elif path == '/info':
            return create_response(200, {
                'function_name': context.function_name,
                'function_version': context.function_version,
                'environment': os.environ.get('ENVIRONMENT', 'unknown'),
                'region': os.environ.get('AWS_REGION', 'unknown'),
                'stage': stage,
                'request_id': context.aws_request_id,
                'runtime': 'python3.9',
                'memory_limit': context.memory_limit_in_mb
            })
            
        elif path == '/version':
            return create_response(200, {
                'api_version': '1.0.0',
                'lambda_version': context.function_version,
                'environment': os.environ.get('ENVIRONMENT', 'unknown'),
                'build_date': '2025-08-12',
                'features': ['routing', 'cors', 'health_checks', 'user_management']
            })
            
        elif path == '/metrics':
            return create_response(200, {
                'request_count': 1,  # This would be stored in a database in real implementation
                'uptime_seconds': 3600,  # Mock data
                'memory_used_mb': context.memory_limit_in_mb * 0.7,
                'environment': os.environ.get('ENVIRONMENT', 'unknown'),
                'timestamp': int(time.time())
            })
            
        elif path == '/docs':
            # Comprehensive API Documentation
            environment = os.environ.get('ENVIRONMENT', 'unknown')
            base_url = f"https://api.{environment}.brainsway.cloud" if environment in ['dev', 'staging'] else "https://api.brainsway.cloud"
            
            # Environment-specific function list
            available_functions = []
            if environment == 'staging':
                available_functions = [
                    'sync_clock-staging - Time synchronization service',
                    'generatePresignedUrl-staging - S3 URL generator',
                    'presignedUrlForS3Upload-staging - S3 upload URL generator',
                    'insert-ppu-data-staging - PPU data insertion',
                    'softwareUpdateHandler-staging - Software update management'
                ]
            elif environment == 'dev':
                available_functions = [
                    'sync_clock-dev - Time synchronization service'
                ]
            
            return create_response(200, {
                'api_documentation': {
                    'title': 'Brainsway Multi-Environment API',
                    'version': '1.0.0',
                    'environment': environment,
                    'base_url': base_url,
                    'description': 'Brainsway API Router with direct Lambda function invocation capabilities',
                    'last_updated': '2025-08-13',
                    'endpoints': {
                        'health': {
                            'path': '/health',
                            'method': 'GET',
                            'description': 'Health check endpoint with system status',
                            'response_format': 'JSON',
                            'example': f'curl {base_url}/health',
                            'response_schema': {
                                'status': 'string',
                                'timestamp': 'string',
                                'environment': 'string',
                                'version': 'string',
                                'checks': 'object'
                            }
                        },
                        'info': {
                            'path': '/info',
                            'method': 'GET',
                            'description': 'Lambda function information and environment details',
                            'response_format': 'JSON',
                            'example': f'curl {base_url}/info'
                        },
                        'version': {
                            'path': '/version',
                            'method': 'GET',
                            'description': 'API version information and feature list',
                            'response_format': 'JSON',
                            'example': f'curl {base_url}/version'
                        },
                        'metrics': {
                            'path': '/metrics',
                            'method': 'GET',
                            'description': 'System metrics and performance indicators',
                            'response_format': 'JSON',
                            'example': f'curl {base_url}/metrics'
                        },
                        'lambda_proxy': {
                            'path': '/lambda/function/{{function_name}}',
                            'methods': ['GET', 'POST', 'PUT', 'DELETE'],
                            'description': 'Direct Lambda function invocation proxy',
                            'response_format': 'JSON',
                            'examples': {
                                'GET': f'curl {base_url}/lambda/function/sync_clock-{environment}',
                                'POST': f'curl -X POST {base_url}/lambda/function/sync_clock-{environment} -H "Content-Type: application/json" -d \'{{"data":"value"}}\'',
                                'PUT': f'curl -X PUT {base_url}/lambda/function/sync_clock-{environment} -H "Content-Type: application/json" -d \'{{"update":"value"}}\'',
                                'DELETE': f'curl -X DELETE {base_url}/lambda/function/sync_clock-{environment}'
                            },
                            'available_functions': available_functions,
                            'notes': [
                                'Replace {{function_name}} with actual Lambda function name',
                                'Functions are environment-specific (e.g., sync_clock-staging for staging)',
                                'All requests support JSON payload in request body',
                                'Responses vary by Lambda function implementation'
                            ]
                        },
                        'docs': {
                            'path': '/docs',
                            'method': 'GET',
                            'description': 'This comprehensive API documentation',
                            'response_format': 'JSON',
                            'example': f'curl {base_url}/docs'
                        }
                    },
                    'authentication': {
                        'type': 'none',
                        'description': 'Currently no authentication required for API endpoints',
                        'notes': 'Production environments may implement API key or JWT authentication'
                    },
                    'cors': {
                        'enabled': True,
                        'allowed_origins': '*',
                        'allowed_methods': ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
                        'allowed_headers': ['Content-Type', 'Authorization', 'X-Requested-With']
                    },
                    'rate_limiting': {
                        'burst_limit': 2000,
                        'rate_limit': 1000,
                        'description': 'API Gateway throttling limits per environment'
                    },
                    'environments': {
                        'development': {
                            'url': 'https://api.dev.brainsway.cloud',
                            'description': 'Development environment for testing and development workflows',
                            'features': ['basic_routing', 'lambda_proxy', 'health_checks']
                        },
                        'staging': {
                            'url': 'https://api.staging.brainsway.cloud', 
                            'description': 'Pre-production environment for validation and testing',
                            'features': ['full_feature_set', 'lambda_proxy', 'monitoring', 'comprehensive_functions']
                        },
                        'production': {
                            'url': 'https://api.brainsway.cloud',
                            'description': 'Production environment (coming soon)',
                            'features': ['enterprise_grade', 'security_hardened', 'high_availability']
                        }
                    }
                }
            })
            
        # /users endpoints removed - no longer supported
                
        elif path.startswith('/lambda/function/'):
            # Handle Lambda function routing pattern: /lambda/function/FUNCTION_NAME
            function_name = path.split('/')[-1]
            if not function_name:
                return create_response(400, {'error': 'Function name is required'})
            
            # Simple routing to Lambda function by name
            if http_method == 'GET':
                return create_response(200, {
                    'function_name': function_name,
                    'status': 'callable',
                    'message': f'Lambda function {function_name} is accessible',
                    'path': path,
                    'available_methods': ['GET', 'POST', 'PUT', 'DELETE'],
                    'timestamp': int(time.time())
                })
            elif http_method == 'POST':
                # Forward POST request to function
                try:
                    request_body = json.loads(body) if body else {}
                    return create_response(200, {
                        'function_name': function_name,
                        'method': 'POST',
                        'received_data': request_body,
                        'message': f'Request forwarded to {function_name}',
                        'timestamp': int(time.time())
                    })
                except json.JSONDecodeError:
                    return create_response(400, {'error': 'Invalid JSON in request body'})
            elif http_method == 'PUT':
                # Handle PUT requests to function
                try:
                    request_body = json.loads(body) if body else {}
                    return create_response(200, {
                        'function_name': function_name,
                        'method': 'PUT',
                        'received_data': request_body,
                        'message': f'PUT request forwarded to {function_name}',
                        'timestamp': int(time.time())
                    })
                except json.JSONDecodeError:
                    return create_response(400, {'error': 'Invalid JSON in request body'})
            elif http_method == 'DELETE':
                # Handle DELETE requests to function
                return create_response(200, {
                    'function_name': function_name,
                    'method': 'DELETE',
                    'message': f'DELETE request forwarded to {function_name}',
                    'timestamp': int(time.time())
                })
            else:
                return create_response(405, {'error': f'Method {http_method} not allowed for Lambda function routing'})
        
        # /users/{id} endpoints removed - no longer supported
        
        else:
            # Default route - return API documentation
            return create_response(200, {
                'message': 'Brainsway API Router',
                'method': http_method,
                'path': path,
                'stage': stage,
                'timestamp': context.aws_request_id,
                'available_endpoints': [
                    'GET /health - Health check endpoint',
                    'GET /info - Function information',
                    'GET /version - API version information',
                    'GET /metrics - System metrics',
                    'GET /lambda/function/{function_name} - Access Lambda function',
                    'POST /lambda/function/{function_name} - Send data to Lambda function',
                    'PUT /lambda/function/{function_name} - Update data via Lambda function',
                    'DELETE /lambda/function/{function_name} - Delete via Lambda function',
                    'GET /docs - API documentation',
                    '/* - Default router'
                ],
                'example_requests': [
                    'curl https://api.staging.brainsway.cloud/health',
                    'curl https://api.staging.brainsway.cloud/info',
                    'curl https://api.staging.brainsway.cloud/version',
                    'curl https://api.staging.brainsway.cloud/metrics',
                    'curl https://api.staging.brainsway.cloud/lambda/function/sync_clock-staging',
                    'curl -X POST https://api.staging.brainsway.cloud/lambda/function/sync_clock-staging -H "Content-Type: application/json" -d \'{"data":"value"}\'',
                    'curl https://api.staging.brainsway.cloud/docs'
                ]
            })
            
    except Exception as e:
        logger.error(f"Error processing request: {str(e)}")
        logger.error(f"Traceback: {traceback.format_exc()}")
        
        return create_response(500, {
            'error': 'Internal server error',
            'request_id': getattr(context, 'aws_request_id', 'unknown'),
            'message': 'An unexpected error occurred'
        })

def create_response(status_code, body, additional_headers=None):
    """Create a properly formatted API Gateway response"""
    
    headers = {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Requested-With'
    }
    
    if additional_headers:
        headers.update(additional_headers)
    
    return {
        'statusCode': status_code,
        'headers': headers,
        'body': json.dumps(body, indent=2)
    }

def create_cors_response():
    """Create a CORS preflight response"""
    return {
        'statusCode': 200,
        'headers': {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Requested-With, X-API-Key',
            'Access-Control-Max-Age': '86400'
        },
        'body': ''
    }
EOT

  default_nodejs_code = <<-EOT
exports.handler = async (event, context) => {
    console.log('Received event:', JSON.stringify({
        httpMethod: event.httpMethod,
        path: event.path,
        resource: event.resource,
        stage: event.requestContext?.stage,
        requestId: event.requestContext?.requestId
    }));
    
    try {
        const httpMethod = event.httpMethod || 'GET';
        const path = event.path || '/';
        const stage = event.requestContext?.stage || 'unknown';
        const headers = event.headers || {};
        const queryParams = event.queryStringParameters || {};
        const pathParams = event.pathParameters || {};
        
        // Basic routing
        if (path === '/health' || path.endsWith('/health')) {
            return createResponse(200, {
                status: 'healthy',
                timestamp: context.awsRequestId,
                environment: process.env.ENVIRONMENT || 'unknown',
                version: '1.0.0'
            });
        }
        
        if (path === '/info' || path.endsWith('/info')) {
            return createResponse(200, {
                functionName: context.functionName,
                functionVersion: context.functionVersion,
                environment: process.env.ENVIRONMENT || 'unknown',
                region: process.env.AWS_REGION || 'unknown',
                stage: stage,
                requestId: context.awsRequestId
            });
        }
        
        if (path === '/docs' || path.endsWith('/docs')) {
            const environment = process.env.ENVIRONMENT || 'unknown';
            const baseUrl = ['dev', 'staging'].includes(environment) 
                ? `https://api.$${environment}.brainsway.cloud`
                : 'https://api.brainsway.cloud';
                
            let availableFunctions = [];
            if (environment === 'staging') {
                availableFunctions = [
                    'sync_clock-staging - Time synchronization service',
                    'generatePresignedUrl-staging - S3 URL generator',
                    'presignedUrlForS3Upload-staging - S3 upload URL generator',
                    'insert-ppu-data-staging - PPU data insertion',
                    'softwareUpdateHandler-staging - Software update management'
                ];
            } else if (environment === 'dev') {
                availableFunctions = [
                    'sync_clock-dev - Time synchronization service'
                ];
            }
            
            return createResponse(200, {
                api_documentation: {
                    title: 'Brainsway Multi-Environment API',
                    version: '1.0.0',
                    environment: environment,
                    base_url: baseUrl,
                    description: 'Brainsway API Router with direct Lambda function invocation capabilities',
                    last_updated: '2025-08-13',
                    endpoints: {
                        health: {
                            path: '/health',
                            method: 'GET',
                            description: 'Health check endpoint with system status',
                            response_format: 'JSON',
                            example: `curl $${baseUrl}/health`
                        },
                        info: {
                            path: '/info',
                            method: 'GET', 
                            description: 'Lambda function information and environment details',
                            response_format: 'JSON',
                            example: `curl ${baseUrl}/info`
                        },
                        lambda_proxy: {
                            path: '/lambda/function/{function_name}',
                            methods: ['GET', 'POST', 'PUT', 'DELETE'],
                            description: 'Direct Lambda function invocation proxy',
                            response_format: 'JSON',
                            examples: {
                                GET: `curl $${baseUrl}/lambda/function/sync_clock-$${environment}`,
                                POST: `curl -X POST $${baseUrl}/lambda/function/sync_clock-$${environment} -H "Content-Type: application/json" -d '{"data":"value"}'`,
                                PUT: `curl -X PUT $${baseUrl}/lambda/function/sync_clock-$${environment} -H "Content-Type: application/json" -d '{"update":"value"}'`,
                                DELETE: `curl -X DELETE $${baseUrl}/lambda/function/sync_clock-$${environment}`
                            },
                            available_functions: availableFunctions,
                            notes: [
                                'Replace {function_name} with actual Lambda function name',
                                'Functions are environment-specific (e.g., sync_clock-staging for staging)',
                                'All requests support JSON payload in request body',
                                'Responses vary by Lambda function implementation'
                            ]
                        },
                        docs: {
                            path: '/docs',
                            method: 'GET',
                            description: 'This comprehensive API documentation',
                            response_format: 'JSON',
                            example: `curl ${baseUrl}/docs`
                        }
                    },
                    authentication: {
                        type: 'none',
                        description: 'Currently no authentication required for API endpoints',
                        notes: 'Production environments may implement API key or JWT authentication'
                    },
                    cors: {
                        enabled: true,
                        allowed_origins: '*',
                        allowed_methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
                        allowed_headers: ['Content-Type', 'Authorization', 'X-Requested-With']
                    },
                    environments: {
                        development: {
                            url: 'https://api.dev.brainsway.cloud',
                            description: 'Development environment for testing and development workflows',
                            features: ['basic_routing', 'lambda_proxy', 'health_checks']
                        },
                        staging: {
                            url: 'https://api.staging.brainsway.cloud',
                            description: 'Pre-production environment for validation and testing', 
                            features: ['full_feature_set', 'lambda_proxy', 'monitoring', 'comprehensive_functions']
                        },
                        production: {
                            url: 'https://api.brainsway.cloud',
                            description: 'Production environment (coming soon)',
                            features: ['enterprise_grade', 'security_hardened', 'high_availability']
                        }
                    }
                }
            });
        }
        
        if (httpMethod === 'OPTIONS') {
            return createCorsResponse();
        }
        
        // Lambda function routing pattern: /lambda/function/FUNCTION_NAME
        if (path.startsWith('/lambda/function/')) {
            const functionName = path.split('/').pop();
            if (!functionName) {
                return createResponse(400, { error: 'Function name is required' });
            }
            
            if (httpMethod === 'GET') {
                return createResponse(200, {
                    function_name: functionName,
                    status: 'callable',
                    message: `Lambda function $${functionName} is accessible`,
                    path: path,
                    available_methods: ['GET', 'POST', 'PUT', 'DELETE'],
                    timestamp: Math.floor(Date.now() / 1000)
                });
            } else if (['POST', 'PUT'].includes(httpMethod)) {
                let requestBody = {};
                try {
                    requestBody = event.body ? JSON.parse(event.body) : {};
                } catch (e) {
                    return createResponse(400, { error: 'Invalid JSON in request body' });
                }
                return createResponse(200, {
                    function_name: functionName,
                    method: httpMethod,
                    received_data: requestBody,
                    message: `$${httpMethod} request forwarded to $${functionName}`,
                    timestamp: Math.floor(Date.now() / 1000)
                });
            } else if (httpMethod === 'DELETE') {
                return createResponse(200, {
                    function_name: functionName,
                    method: 'DELETE',
                    message: `DELETE request forwarded to $${functionName}`,
                    timestamp: Math.floor(Date.now() / 1000)
                });
            } else {
                return createResponse(405, { error: `Method $${httpMethod} not allowed for Lambda function routing` });
            }
        }
        
        // Default route
        return createResponse(200, {
            message: 'API Router is working',
            method: httpMethod,
            path: path,
            stage: stage,
            timestamp: context.awsRequestId,
            availableEndpoints: [
                '/health - Health check endpoint',
                '/info - Function information',
                '/lambda/function/{function_name} - Access Lambda function',
                '/docs - API documentation',
                '/* - This default router'
            ]
        });
        
    } catch (error) {
        console.error('Error processing request:', error);
        
        return createResponse(500, {
            error: 'Internal server error',
            requestId: context.awsRequestId,
            message: 'An unexpected error occurred'
        });
    }
};

function createResponse(statusCode, body, additionalHeaders = {}) {
    const headers = {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Requested-With',
        ...additionalHeaders
    };
    
    return {
        statusCode: statusCode,
        headers: headers,
        body: JSON.stringify(body, null, 2)
    };
}

function createCorsResponse() {
    return {
        statusCode: 200,
        headers: {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Requested-With, X-API-Key',
            'Access-Control-Max-Age': '86400'
        },
        body: ''
    };
}
EOT

  # Choose default code based on runtime
  default_code = startswith(var.lambda_runtime, "python") ? local.default_python_code : local.default_nodejs_code
  default_filename = startswith(var.lambda_runtime, "python") ? "index.py" : "index.js"
}

# Create temporary directory for Lambda code if needed
resource "local_file" "default_lambda_code" {
  count = var.create_default_code && var.source_code_path == null ? 1 : 0
  
  content  = local.default_code
  filename = "${path.module}/temp/${local.default_filename}"
  
  lifecycle {
    create_before_destroy = true
  }
}

# Create Lambda deployment package
data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = var.source_code_path != null ? "${var.source_code_path}/../${var.function_name}.zip" : "${path.module}/temp/${var.function_name}.zip"
  
  # Use provided source code or default code
  source_dir = var.source_code_path != null ? var.source_code_path : (
    var.create_default_code ? "${path.module}/temp" : null
  )
  
  depends_on = [local_file.default_lambda_code]
}

# Lambda execution role (if not provided)
data "aws_iam_policy_document" "lambda_assume_role" {
  count = var.execution_role_arn == null ? 1 : 0
  
  statement {
    effect = "Allow"
    
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
    
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "lambda_execution" {
  count = var.execution_role_arn == null ? 1 : 0
  
  name_prefix        = "${substr(var.function_name, 0, 20)}-exec-"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role[0].json
  
  tags = merge(var.tags, {
    Name        = "${var.function_name}-execution-role"
    Environment = var.environment
    Purpose     = "Lambda Execution"
  })
}

# Basic Lambda execution policy
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  count = var.execution_role_arn == null ? 1 : 0
  
  role       = aws_iam_role.lambda_execution[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# VPC access policy (if VPC config is provided)
resource "aws_iam_role_policy_attachment" "lambda_vpc_access" {
  count = var.execution_role_arn == null && var.vpc_config != null ? 1 : 0
  
  role       = aws_iam_role.lambda_execution[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# X-Ray tracing policy (if tracing is enabled)
resource "aws_iam_role_policy_attachment" "lambda_xray_write" {
  count = var.execution_role_arn == null && var.enable_tracing ? 1 : 0
  
  role       = aws_iam_role.lambda_execution[0].name
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

# Dead Letter Queue permissions (if DLQ is enabled)
data "aws_iam_policy_document" "dlq_policy" {
  count = var.execution_role_arn == null && var.enable_dlq ? 1 : 0
  
  statement {
    effect = "Allow"
    
    actions = [
      "sqs:SendMessage",
      "sqs:GetQueueAttributes"
    ]
    
    resources = [
      var.dlq_target_arn != null ? var.dlq_target_arn : aws_sqs_queue.dlq[0].arn
    ]
  }
}

resource "aws_iam_role_policy" "lambda_dlq_policy" {
  count = var.execution_role_arn == null && var.enable_dlq ? 1 : 0
  
  name_prefix = "${var.function_name}-dlq-policy-"
  role        = aws_iam_role.lambda_execution[0].id
  policy      = data.aws_iam_policy_document.dlq_policy[0].json
}

# Additional policies
resource "aws_iam_role_policy" "additional_policies" {
  count = var.execution_role_arn == null && length(var.additional_policy_documents) > 0 ? length(var.additional_policy_documents) : 0
  
  name_prefix = "${var.function_name}-additional-policy-"
  role        = aws_iam_role.lambda_execution[0].id
  policy      = var.additional_policy_documents[count.index]
}

# Dead Letter Queue (SQS)
resource "aws_sqs_queue" "dlq" {
  count = var.enable_dlq && var.dlq_target_arn == null ? 1 : 0
  
  name_prefix               = "${var.function_name}-dlq-"
  message_retention_seconds = 1209600  # 14 days
  
  tags = merge(var.tags, {
    Name        = "${var.function_name}-dlq"
    Environment = var.environment
    Purpose     = "Lambda Dead Letter Queue"
  })
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = var.log_retention_in_days
  
  tags = merge(var.tags, {
    Name        = "${var.function_name}-logs"
    Environment = var.environment
    Purpose     = "Lambda Logs"
  })
}

# Lambda Function
resource "aws_lambda_function" "this" {
  function_name                  = var.function_name
  role                          = var.execution_role_arn != null ? var.execution_role_arn : aws_iam_role.lambda_execution[0].arn
  handler                       = var.lambda_handler
  runtime                       = var.lambda_runtime
  timeout                       = var.lambda_timeout
  memory_size                   = var.lambda_memory_size
  reserved_concurrent_executions = var.reserved_concurrent_executions != -1 ? var.reserved_concurrent_executions : null
  
  # Code configuration - S3 source takes precedence
  s3_bucket = var.lambda_code_s3_bucket
  s3_key    = var.lambda_code_s3_key
  
  # Local file source (used when S3 is not specified)
  filename         = var.lambda_code_s3_bucket == null ? data.archive_file.lambda_zip.output_path : null
  source_code_hash = var.lambda_code_s3_bucket == null ? data.archive_file.lambda_zip.output_base64sha256 : null
  
  # Environment variables
  dynamic "environment" {
    for_each = length(var.environment_variables) > 0 ? [1] : []
    content {
      variables = merge(var.environment_variables, {
        ENVIRONMENT    = var.environment
        FUNCTION_NAME  = var.function_name
        LOG_LEVEL      = "INFO"
      })
    }
  }
  
  # VPC configuration
  dynamic "vpc_config" {
    for_each = var.vpc_config != null ? [var.vpc_config] : []
    content {
      subnet_ids         = vpc_config.value.subnet_ids
      security_group_ids = vpc_config.value.security_group_ids
    }
  }
  
  # Dead Letter Queue
  dynamic "dead_letter_config" {
    for_each = var.enable_dlq ? [1] : []
    content {
      target_arn = var.dlq_target_arn != null ? var.dlq_target_arn : aws_sqs_queue.dlq[0].arn
    }
  }
  
  # X-Ray tracing
  dynamic "tracing_config" {
    for_each = var.enable_tracing ? [1] : []
    content {
      mode = var.tracing_mode
    }
  }
  
  # KMS encryption
  kms_key_arn = var.kms_key_arn
  
  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic_execution,
    aws_iam_role_policy_attachment.lambda_vpc_access,
    aws_iam_role_policy_attachment.lambda_xray_write,
    aws_cloudwatch_log_group.lambda_logs,
  ]
  
  tags = merge(var.tags, {
    Name        = var.function_name
    Environment = var.environment
    Runtime     = var.lambda_runtime
    Purpose     = "API Router"
  })
}

# Provisioned concurrency (if configured)
resource "aws_lambda_provisioned_concurrency_config" "this" {
  count = var.provisioned_concurrency_config != null ? 1 : 0
  
  function_name                     = aws_lambda_function.this.function_name
  provisioned_concurrent_executions = var.provisioned_concurrency_config.provisioned_concurrent_executions
  qualifier                         = aws_lambda_function.this.version
  
  depends_on = [aws_lambda_function.this]
}

# API Gateway Lambda permission (if API Gateway integration is provided)
resource "aws_lambda_permission" "api_gateway" {
  count = var.api_gateway_integration != null ? 1 : 0
  
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${var.api_gateway_integration.api_gateway_execution_arn}/*/*"
}

# Event Source Mappings
resource "aws_lambda_event_source_mapping" "this" {
  count = length(var.event_source_mappings)
  
  event_source_arn                   = var.event_source_mappings[count.index].event_source_arn
  function_name                      = aws_lambda_function.this.arn
  starting_position                  = var.event_source_mappings[count.index].starting_position
  batch_size                         = var.event_source_mappings[count.index].batch_size
  maximum_batching_window_in_seconds = var.event_source_mappings[count.index].maximum_batching_window_in_seconds
  parallelization_factor             = var.event_source_mappings[count.index].parallelization_factor
  enabled                            = var.event_source_mappings[count.index].enabled
  
  dynamic "filter_criteria" {
    for_each = var.event_source_mappings[count.index].filter_criteria != null ? [var.event_source_mappings[count.index].filter_criteria] : []
    content {
      dynamic "filter" {
        for_each = filter_criteria.value.filters
        content {
          pattern = filter.value.pattern
        }
      }
    }
  }
}

# CloudWatch Alarms (if monitoring is enabled)
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  count = var.enable_monitoring ? 1 : 0
  
  alarm_name          = "${var.function_name}-error-rate-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "Lambda function ${var.function_name} error rate alarm"
  alarm_actions       = var.alarm_sns_topic_arns
  ok_actions          = var.alarm_sns_topic_arns
  treat_missing_data  = "notBreaching"
  
  dimensions = {
    FunctionName = aws_lambda_function.this.function_name
  }
  
  tags = merge(var.tags, {
    Name        = "${var.function_name}-error-alarm"
    Environment = var.environment
  })
}

resource "aws_cloudwatch_metric_alarm" "lambda_duration" {
  count = var.enable_monitoring ? 1 : 0
  
  alarm_name          = "${var.function_name}-duration-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Average"
  threshold           = var.duration_threshold_ms
  alarm_description   = "Lambda function ${var.function_name} duration alarm"
  alarm_actions       = var.alarm_sns_topic_arns
  treat_missing_data  = "notBreaching"
  
  dimensions = {
    FunctionName = aws_lambda_function.this.function_name
  }
  
  tags = merge(var.tags, {
    Name        = "${var.function_name}-duration-alarm"
    Environment = var.environment
  })
}