# Multi-Account API Gateway DNS Implementation Plan

**Date:** 2025-01-12  
**Status:** ✅ Modules Complete - Terragrunt Configs In Progress  
**Environment:** brainsway-infra repository  

## Summary

Successfully implemented comprehensive multi-account API Gateway DNS delegation system with enhanced security hardening features. All core modules have been created and are ready for deployment via Terragrunt configurations.

## 🏗️ Infrastructure Architecture

### Target Architecture
- **dev:** api.dev.brainsway.cloud (Account: 824357028182)
- **staging:** api.staging.brainsway.cloud (Account: 574210586915) 
- **prod:** api.brainsway.cloud (Account: 154948530138)

### Key Components
1. **HTTP API Gateway v2** with Lambda proxy integration
2. **Route53 DNS delegation** with cross-account subzone creation
3. **ACM SSL certificates** with DNS validation
4. **Lambda router** with comprehensive monitoring
5. **Optional WAFv2** protection with customizable rules

## ✅ Completed Modules

### 1. Enhanced API Gateway HTTP Proxy (`infra/modules/apigw_http_proxy/`)
**Status:** ✅ Complete with Security Hardening

**Key Features:**
- HTTP API Gateway v2 with Lambda proxy integration
- CORS configuration with customizable origins/methods/headers
- CloudWatch logging with configurable log format
- Custom domain support with ACM certificate integration
- Optional WAFv2 integration
- Lambda invoke permissions with least privilege
- Comprehensive monitoring and alerting

**Security Enhancements:**
- Request/response size limits
- Throttling configuration per route/stage
- API key authentication support
- Request validation
- Access logging with sanitization

### 2. Route53 Subzone Module (`infra/modules/route53/subzone/`)
**Status:** ✅ Complete

**Key Features:**
- Delegated hosted zone creation (e.g., dev.brainsway.cloud)
- Health checks for api endpoints
- CloudWatch query logging
- Comprehensive monitoring with failure/latency alarms
- Delegation metadata records for tracking

### 3. Route53 Delegate Subzone Module (`infra/modules/route53/delegate_subzone/`)
**Status:** ✅ Complete

**Key Features:**
- NS record creation in parent zone for delegation
- DNS validation with automated testing
- Health monitoring of delegated zones
- CloudWatch alarms for delegation failures
- Delegation metadata with environment tracking

### 4. ACM Certificate DNS Module (`infra/modules/acm/cert_dns/`)
**Status:** ✅ Complete

**Key Features:**
- SSL certificate with DNS validation
- Subject Alternative Names (SAN) support
- Certificate expiration monitoring
- Cross-account certificate sharing capability
- Auto-renewal with early renewal duration
- Certificate transparency logging

### 5. Lambda Router Module (`infra/modules/lambda/router/`)
**Status:** ✅ Complete

**Key Features:**
- Production-ready Lambda function with default API routing code
- Support for Python 3.11 and Node.js 20.x runtimes
- API Gateway integration with proper permissions
- Dead Letter Queue configuration
- X-Ray tracing support
- VPC support for enhanced security
- Comprehensive CloudWatch monitoring
- Provisioned concurrency support

**Built-in API Endpoints:**
- `/health` - Health check endpoint
- `/info` - Function information
- `/*` - Default router with CORS support

### 6. WAFv2 Web ACL Module (`infra/modules/wafv2/web_acl/`)
**Status:** ✅ Complete (Optional)

**Key Features:**
- Rate limiting with configurable thresholds
- IP allowlist/blocklist support
- Geographic restrictions (country blocking/allowing)
- AWS Managed Rule Groups integration
- Custom rule support (SQLi, XSS, byte matching, size constraints)
- CloudWatch logging and monitoring
- Automatic resource association

**Security Rules Included:**
- AWSManagedRulesCommonRuleSet
- AWSManagedRulesKnownBadInputsRuleSet
- AWSManagedRulesSQLiRuleSet
- AWSManagedRulesLinuxRuleSet
- AWSManagedRulesUnixRuleSet

## 🔧 Implementation Details

### Module Relationships
```
API Gateway HTTP Proxy
├── ACM Certificate (SSL/TLS)
├── Lambda Router (Backend)
├── Route53 Subzone (DNS)
│   └── Route53 Delegate (Parent zone NS records)
└── WAFv2 Web ACL (Optional security)
```

### Cross-Account Configuration
- **Dev Account (824357028182):** Creates dev.brainsway.cloud subzone
- **Staging Account (574210586915):** Creates staging.brainsway.cloud subzone  
- **Prod Account (154948530138):** Manages brainsway.cloud parent zone + delegates subzones

### Security Hardening Features
- **Lambda Invoke Permissions:** Restrictive API Gateway-only access
- **CloudWatch Logging:** Comprehensive request/response logging
- **CORS Controls:** Configurable origin restrictions
- **WAFv2 Integration:** Optional DDoS/attack protection
- **Certificate Monitoring:** Expiration alerts and auto-renewal
- **Health Checks:** DNS and API endpoint monitoring
- **Rate Limiting:** Configurable per-IP throttling

## 🚧 Current Work In Progress

### Next Steps: Terragrunt Configurations
Currently creating Terragrunt configurations for:

1. **Dev Environment:** `infra/live/dev/us-east-2/api-gateway/`
2. **Staging Environment:** `infra/live/staging/us-east-2/api-gateway/`
3. **Production Environment:** `infra/live/prod/us-east-2/api-gateway/`

### Dependencies Resolution
- Cross-account provider configuration in root `terragrunt.hcl`
- Environment-specific variable files
- Resource dependency ordering (certificates → DNS → API Gateway)

## 📋 Deployment Sequence

### Phase 1: Certificate and DNS (All Environments)
1. Create ACM certificates with DNS validation
2. Create Route53 subzones
3. Create delegation NS records in parent zone

### Phase 2: Lambda and API Gateway
1. Deploy Lambda router function
2. Create HTTP API Gateway with custom domain
3. Configure CORS and logging

### Phase 3: Security and Monitoring (Optional)
1. Deploy WAFv2 Web ACL
2. Associate with API Gateway
3. Configure CloudWatch alarms

## 🔐 Security Considerations

### Implemented Security Controls
- ✅ **Encryption in Transit:** ACM SSL certificates
- ✅ **Access Controls:** Lambda invoke permissions
- ✅ **Request Filtering:** WAFv2 with AWS managed rules  
- ✅ **Rate Limiting:** Per-IP throttling
- ✅ **Monitoring:** CloudWatch logs and alarms
- ✅ **DNS Security:** Health checks and validation
- ✅ **CORS Protection:** Configurable origin restrictions

### Compliance Features
- Certificate transparency logging (configurable)
- Request/response logging with PII redaction
- Geographic access controls
- Audit trail through CloudWatch and X-Ray

## 📊 Monitoring and Observability

### CloudWatch Metrics
- API Gateway: Request count, latency, error rates
- Lambda: Duration, errors, concurrent executions
- Route53: Health check status, query volume
- ACM: Certificate expiration warnings
- WAF: Blocked/allowed requests, rule matches

### Alerting
- Certificate expiration (30 days warning)
- API Gateway high error rates
- Lambda function errors/duration
- DNS delegation failures
- WAF attack detection

## 🧪 Testing Strategy

### Validation Commands Included
Each module outputs specific testing commands:
- DNS resolution testing (`dig`, `nslookup`)
- SSL certificate validation (`openssl`)
- API endpoint testing (`curl`, AWS CLI)
- WAF rule testing (sample requests)

### Health Check Endpoints
- `/health` - Application health status
- `/info` - Runtime information and diagnostics

## 📝 Configuration Examples

### Minimal Configuration
```hcl
# Basic API Gateway with Lambda
api_name = "brainsway-api"
domain_name = "api.dev.brainsway.cloud"
lambda_runtime = "python3.11"
```

### Production Configuration  
```hcl
# Full security hardening
enable_waf = true
enable_cors = true
cors_allow_origins = ["https://app.brainsway.cloud"]
rate_limit = 1000
enable_certificate_monitoring = true
enable_health_check = true
```

## 📖 Documentation

### Module Documentation
Each module includes:
- Comprehensive variable descriptions with validation
- Output values for integration
- Usage examples and testing commands
- Security considerations and best practices

### Operational Runbooks
- Deployment procedures
- Troubleshooting guides  
- Security incident response
- Certificate renewal procedures

---

**Next Action:** Complete Terragrunt configurations for dev environment, then staging and production environments.