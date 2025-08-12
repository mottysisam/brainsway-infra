data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# Default Lambda code (if source_code_path is not provided)
locals {
  default_python_code = <<-EOT
import json
import logging
import os
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
        # Log the incoming event (sanitized)
        logger.info(f"Received event: {json.dumps({
            'httpMethod': event.get('httpMethod'),
            'path': event.get('path'),
            'resource': event.get('resource'),
            'stage': event.get('requestContext', {}).get('stage'),
            'requestId': event.get('requestContext', {}).get('requestId')
        })}")
        
        # Extract request information
        http_method = event.get('httpMethod', 'GET')
        path = event.get('path', '/')
        stage = event.get('requestContext', {}).get('stage', 'unknown')
        headers = event.get('headers', {})
        query_params = event.get('queryStringParameters') or {}
        path_params = event.get('pathParameters') or {}
        
        # Basic routing logic
        if path == '/health' or path.endswith('/health'):
            return create_response(200, {
                'status': 'healthy',
                'timestamp': context.aws_request_id,
                'environment': os.environ.get('ENVIRONMENT', 'unknown'),
                'version': '1.0.0'
            })
        
        elif path == '/info' or path.endswith('/info'):
            return create_response(200, {
                'function_name': context.function_name,
                'function_version': context.function_version,
                'environment': os.environ.get('ENVIRONMENT', 'unknown'),
                'region': os.environ.get('AWS_REGION', 'unknown'),
                'stage': stage,
                'request_id': context.aws_request_id
            })
        
        elif http_method == 'OPTIONS':
            # Handle CORS preflight requests
            return create_cors_response()
        
        else:
            # Default route - return method and path information
            return create_response(200, {
                'message': 'API Router is working',
                'method': http_method,
                'path': path,
                'stage': stage,
                'timestamp': context.aws_request_id,
                'available_endpoints': [
                    '/health - Health check endpoint',
                    '/info - Function information',
                    '/* - This default router'
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
        
        if (httpMethod === 'OPTIONS') {
            return createCorsResponse();
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
  
  name_prefix        = "${var.function_name}-execution-"
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