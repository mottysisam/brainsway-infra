data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# Internal Router Lambda - Node.js 20.x for AWS SDK v3 performance
locals {
  internal_router_code = <<-EOT
import { LambdaClient, InvokeCommand } from "@aws-sdk/client-lambda";

// Cache for function map (5 min)
let cache = { at: 0, map: null };
const CACHE_MS = parseInt(process.env.CACHE_TTL_MS || "300000"); // 5 minutes

const lambda = new LambdaClient({});

async function loadFunctionMap() {
  // Check cache first
  if (cache.map && Date.now() - cache.at < CACHE_MS) return cache.map;
  
  const raw = process.env.FUNCTION_MAP;
  if (!raw) throw new Error("FUNCTION_MAP environment variable missing");
  
  try {
    const map = JSON.parse(raw);
    cache = { at: Date.now(), map };
    return map;
  } catch (e) {
    throw new Error(`Invalid FUNCTION_MAP JSON: $${e.message}`);
  }
}

function createResponse(statusCode, body, headers = {}) {
  return {
    statusCode,
    headers: { 
      "Content-Type": "application/json", 
      "X-Request-ID": headers["X-Request-ID"] || crypto.randomUUID?.() || `$${Date.now()}`,
      ...headers 
    },
    body: JSON.stringify(body),
  };
}

export const handler = async (event) => {
  const reqId = event.headers?.["x-request-id"] || crypto.randomUUID?.() || `$${Date.now()}`;
  const method = event.requestContext?.http?.method || "GET";
  const rawPath = event.rawPath || "/";
  const functionName = event.pathParameters?.function_name; // from /lambda/function/{function_name+}

  console.log(JSON.stringify({
    level: "INFO",
    message: "Internal router request",
    requestId: reqId,
    method,
    path: rawPath,
    functionName,
    sourceIp: event.requestContext?.http?.sourceIp,
    principalId: event.requestContext?.authorizer?.iam?.userId || null,
  }));

  // Method validation (allow most common HTTP methods)
  const allowedMethods = new Set(["GET", "POST", "PUT", "DELETE", "PATCH", "HEAD", "OPTIONS"]);
  if (!allowedMethods.has(method)) {
    console.log(JSON.stringify({
      level: "WARN",
      message: "Method not allowed",
      requestId: reqId,
      method,
      functionName,
    }));
    return createResponse(405, { error: "method_not_allowed", method }, { "X-Request-ID": reqId });
  }

  // Function name validation
  if (!functionName) {
    console.log(JSON.stringify({
      level: "WARN", 
      message: "Missing function name",
      requestId: reqId,
      path: rawPath,
    }));
    return createResponse(404, { error: "function_name_required" }, { "X-Request-ID": reqId });
  }

  // Check if direct invocation mode is enabled
  const enableDirectInvocation = process.env.ENABLE_DIRECT_INVOCATION === "true";
  let targetArn = null;
  
  if (!enableDirectInvocation) {
    // Traditional mapping-based approach
    let functionMap;
    try {
      functionMap = await loadFunctionMap();
    } catch (e) {
      console.error(JSON.stringify({
        level: "ERROR",
        message: "Function map load error",
        requestId: reqId,
        error: e.message,
      }));
      return createResponse(500, { error: "internal_config_error" }, { "X-Request-ID": reqId });
    }

    targetArn = functionMap[functionName];
    if (!targetArn) {
      console.log(JSON.stringify({
        level: "WARN",
        message: "Unknown function name in mapping",
        requestId: reqId,
        functionName,
        availableFunctions: Object.keys(functionMap),
      }));
      return createResponse(404, { 
        error: "unknown_function", 
        function_name: functionName,
        available_functions: Object.keys(functionMap)
      }, { "X-Request-ID": reqId });
    }
  } else {
    // Direct invocation mode - construct ARN from function name
    const awsRegion = process.env.AWS_REGION || "us-east-2";
    const awsAccountId = process.env.AWS_ACCOUNT_ID;
    targetArn = `arn:aws:lambda:$${awsRegion}:$${awsAccountId}:function:$${functionName}`;
    
    console.log(JSON.stringify({
      level: "INFO",
      message: "Direct invocation mode - constructing ARN",
      requestId: reqId,
      functionName,
      targetArn,
    }));
  }

  // Build payload for target Lambda
  const payload = {
    _meta: {
      from: "internal-router",
      requestId: reqId,
      functionName,
      method,
      path: rawPath,
      sourceIp: event.requestContext?.http?.sourceIp,
      principalId: event.requestContext?.authorizer?.iam?.userId || null,
      timestamp: new Date().toISOString(),
    },
    httpMethod: method, // For compatibility with existing Lambdas
    path: rawPath,
    pathParameters: event.pathParameters || {},
    queryStringParameters: event.queryStringParameters || {},
    headers: event.headers || {},
    body: event.body && event.isBase64Encoded ? 
      Buffer.from(event.body, "base64").toString() : event.body,
    isBase64Encoded: event.isBase64Encoded || false,
    requestContext: event.requestContext || {},
  };

  const startTime = Date.now();
  
  try {
    console.log(JSON.stringify({
      level: "INFO",
      message: "Invoking target Lambda",
      requestId: reqId,
      functionName,
      targetArn,
    }));

    const res = await lambda.send(
      new InvokeCommand({
        FunctionName: targetArn,
        InvocationType: "RequestResponse",
        Payload: Buffer.from(JSON.stringify(payload)),
      })
    );

    const duration = Date.now() - startTime;
    const status = res.StatusCode ?? 200;

    // Parse Lambda response
    let lambdaResponse = {};
    if (res.Payload) {
      try {
        lambdaResponse = JSON.parse(Buffer.from(res.Payload).toString() || "{}");
      } catch (e) {
        console.error(JSON.stringify({
          level: "ERROR",
          message: "Invalid Lambda response JSON",
          requestId: reqId,
          functionName,
          error: e.message,
        }));
        return createResponse(502, { error: "invalid_lambda_response" }, { "X-Request-ID": reqId });
      }
    }

    console.log(JSON.stringify({
      level: "INFO",
      message: "Lambda invocation completed",
      requestId: reqId,
      functionName,
      targetArn,
      duration,
      statusCode: lambdaResponse.statusCode || status,
    }));

    // Return Lambda response (proxy style)
    const response = {
      statusCode: lambdaResponse.statusCode ?? (status >= 200 && status < 400 ? 200 : 502),
      headers: { 
        ...(lambdaResponse.headers || {}), 
        "X-Request-ID": reqId,
        "X-Function-Name": functionName,
        "X-Duration-MS": duration.toString(),
      },
      body: typeof lambdaResponse.body === "string" ? 
        lambdaResponse.body : JSON.stringify(lambdaResponse.body ?? lambdaResponse),
    };

    return response;

  } catch (err) {
    const duration = Date.now() - startTime;
    
    console.error(JSON.stringify({
      level: "ERROR",
      message: "Lambda invocation failed",
      requestId: reqId,
      functionName,
      targetArn,
      duration,
      error: err.message,
      errorCode: err.code,
    }));

    return createResponse(502, { 
      error: "lambda_invoke_failed", 
      function_name: functionName,
      message: "Target Lambda invocation failed"
    }, { "X-Request-ID": reqId });
  }
};
EOT

  default_filename = "index.mjs"
}

# Create Lambda deployment package
resource "local_file" "internal_router_code" {
  content  = local.internal_router_code
  filename = "${path.module}/temp/${local.default_filename}"

  lifecycle {
    create_before_destroy = true
  }
}

data "archive_file" "internal_router_zip" {
  type        = "zip"
  output_path = "${path.module}/temp/${var.function_name}.zip"
  source_dir  = "${path.module}/temp"
  
  depends_on = [local_file.internal_router_code]
}

# IAM role for internal router Lambda
data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect = "Allow"
    
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
    
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "internal_router_execution" {
  name_prefix        = "${substr(var.function_name, 0, 20)}-exec-"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
  
  tags = merge(var.tags, {
    Name        = "${var.function_name}-execution-role"
    Environment = var.environment
    Purpose     = "Internal Lambda Router"
  })
}

# Basic Lambda execution policy
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.internal_router_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Lambda invocation policy - restricted to specific ARNs or wildcard for direct invocation
data "aws_iam_policy_document" "lambda_invoke_policy" {
  statement {
    effect = "Allow"
    
    actions = [
      "lambda:InvokeFunction"
    ]
    
    # If direct invocation is enabled, allow invoking any function in the account
    # Otherwise, restrict to specific ARNs
    resources = var.enable_direct_invocation ? [
      "arn:aws:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:function:*"
    ] : var.allowed_lambda_arns
  }
}

resource "aws_iam_role_policy" "lambda_invoke_policy" {
  name_prefix = "${var.function_name}-invoke-policy-"
  role        = aws_iam_role.internal_router_execution.id
  policy      = data.aws_iam_policy_document.lambda_invoke_policy.json
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "internal_router_logs" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = var.log_retention_in_days
  
  tags = merge(var.tags, {
    Name        = "${var.function_name}-logs"
    Environment = var.environment
    Purpose     = "Internal Router Logs"
  })
}

# Internal Router Lambda Function
resource "aws_lambda_function" "internal_router" {
  function_name = var.function_name
  role         = aws_iam_role.internal_router_execution.arn
  handler      = "index.handler"
  runtime      = "nodejs20.x"
  timeout      = var.lambda_timeout
  memory_size  = var.lambda_memory_size
  
  filename         = data.archive_file.internal_router_zip.output_path
  source_code_hash = data.archive_file.internal_router_zip.output_base64sha256
  
  environment {
    variables = merge(var.environment_variables, {
      ENVIRONMENT         = var.environment
      FUNCTION_NAME       = var.function_name
      LOG_LEVEL           = "INFO"
      CACHE_TTL_MS        = "300000" # 5 minutes
      ENABLE_DIRECT_INVOCATION = tostring(var.enable_direct_invocation)
      AWS_ACCOUNT_ID      = data.aws_caller_identity.current.account_id
    })
  }
  
  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic_execution,
    aws_iam_role_policy.lambda_invoke_policy,
    aws_cloudwatch_log_group.internal_router_logs,
  ]
  
  tags = merge(var.tags, {
    Name        = var.function_name
    Environment = var.environment
    Runtime     = "nodejs20.x"
    Purpose     = "Internal Lambda Router"
  })
}

# CloudWatch alarms for monitoring
resource "aws_cloudwatch_metric_alarm" "internal_router_errors" {
  count = var.enable_monitoring ? 1 : 0
  
  alarm_name          = "${var.function_name}-error-rate-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "Internal router ${var.function_name} error rate alarm"
  alarm_actions       = var.alarm_sns_topic_arns
  ok_actions          = var.alarm_sns_topic_arns
  treat_missing_data  = "notBreaching"
  
  dimensions = {
    FunctionName = aws_lambda_function.internal_router.function_name
  }
  
  tags = merge(var.tags, {
    Name        = "${var.function_name}-error-alarm"
    Environment = var.environment
  })
}

resource "aws_cloudwatch_metric_alarm" "internal_router_duration" {
  count = var.enable_monitoring ? 1 : 0
  
  alarm_name          = "${var.function_name}-duration-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Average"
  threshold           = var.duration_threshold_ms
  alarm_description   = "Internal router ${var.function_name} duration alarm"
  alarm_actions       = var.alarm_sns_topic_arns
  treat_missing_data  = "notBreaching"
  
  dimensions = {
    FunctionName = aws_lambda_function.internal_router.function_name
  }
  
  tags = merge(var.tags, {
    Name        = "${var.function_name}-duration-alarm"
    Environment = var.environment
  })
}