# AWS Deployment Verification System Setup

This document provides setup instructions for the smart AWS deployment verification and notification system implemented for the brainsway-infra repository.

## Overview

The verification system provides:
- **Post-deployment resource verification** with AWS CLI probing
- **Eventual consistency handling** with configurable retry logic
- **Comprehensive reporting** in JSON format with HTML email notifications  
- **Production-ready error handling** and detailed logging
- **CI/CD integration** with GitHub Actions and PR status updates

## Architecture

```
GitHub Actions (iac.yml)
├── Terragrunt Deployment
├── AWS Resource Verification
│   ├── Core Script (verify-deployment.sh)
│   └── Modular Probe Scripts
│       ├── rds-probe.sh
│       ├── ec2-probe.sh  
│       ├── lambda-probe.sh
│       ├── dynamodb-probe.sh
│       ├── s3-probe.sh
│       ├── apigateway-probe.sh
│       └── iam-probe.sh
├── Report Generation & Upload
└── Email Notifications (SMTP)
```

## Required GitHub Secrets Configuration

The system requires the following repository secrets to be configured:

### SMTP Configuration (Required for Email Notifications)

1. **SMTP_SERVER** - Your SMTP server hostname
   ```
   Example: smtp.gmail.com
   ```

2. **SMTP_PORT** - SMTP server port (typically 587 for TLS)
   ```
   Example: 587
   ```

3. **SMTP_USERNAME** - SMTP authentication username
   ```
   Example: your-email@company.com
   ```

4. **SMTP_PASSWORD** - SMTP authentication password/app-specific password
   ```
   Example: your-app-specific-password
   ```

5. **NOTIFICATION_EMAIL** - Email address to receive deployment reports
   ```
   Example: devops-team@company.com
   ```

### Setting GitHub Secrets

1. Go to your repository on GitHub
2. Navigate to **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Add each secret listed above

#### Gmail Setup Example

For Gmail SMTP, you'll need:
- **SMTP_SERVER**: `smtp.gmail.com`
- **SMTP_PORT**: `587`
- **SMTP_USERNAME**: Your Gmail address
- **SMTP_PASSWORD**: Generate an [App-Specific Password](https://support.google.com/accounts/answer/185833)
- **NOTIFICATION_EMAIL**: Target email for reports

## Verification Process Flow

1. **Trigger**: After successful Terragrunt `apply` operations
2. **Initial Wait**: 30-second delay for AWS eventual consistency
3. **Resource Probing**: Each service probe script runs with retry logic
4. **Report Generation**: JSON report with verification results
5. **Email Notification**: Rich HTML email with attached JSON report
6. **GitHub Integration**: PR comments updated with verification status

## Resource Verification Coverage

The system verifies these AWS services:

### RDS (Database)
- **Instances**: Per-environment database instances with health checks
- **Connectivity**: TCP connection tests to database endpoints
- **Configuration**: Engine, version, storage, multi-AZ settings

### EC2 (Compute)  
- **Instances**: Server instances with status checks
- **Networking**: VPC, subnet, security group validation
- **Connectivity**: SSH/RDP port accessibility tests

### Lambda (Serverless)
- **Functions**: Runtime, state, configuration validation
- **Code**: Size, timeout, memory configuration checks

### DynamoDB (NoSQL)
- **Tables**: Status, billing mode, encryption settings
- **Performance**: Item count and size metrics

### S3 (Storage)
- **Buckets**: Existence, region, versioning status
- **Security**: Public access blocking, encryption settings

### API Gateway (APIs)
- **REST APIs**: Endpoint existence, stage deployment
- **Resources**: API resource count and configuration

### IAM (Access Control)
- **Roles**: Role existence, policy attachments
- **Policies**: Custom policy validation and usage

## Expected Resources by Environment

### Development Environment
- RDS: `bwppudb-dev`
- EC2: `aurora-jump-server-dev`, `insights-dev-backend`, `insights-dev-frontend`
- Lambda: `insert-ppu-data-dev`, `generatePresignedUrl-dev`, `presignedUrlForS3Upload-dev`, `sync_clock-dev`, `softwareUpdateHandler-dev`
- DynamoDB: `event_log-dev`, `sw_update-dev`
- S3: `bw-tf-state-dev-us-east-2`, `bw-ppu-data-dev`, `bw-software-updates-dev`
- API Gateway: `bw-ppu-api-dev`

### Staging Environment
- RDS: `bwppudb-staging`
- EC2: `aurora-jump-server-staging`, `insights-staging-backend`, `insights-staging-frontend`
- Lambda: `insert-ppu-data-staging`, `generatePresignedUrl-staging`, `presignedUrlForS3Upload-staging`, `sync_clock-staging`, `softwareUpdateHandler-staging`
- DynamoDB: `event_log-staging`, `sw_update-staging`
- S3: `bw-tf-state-staging-us-east-2`, `bw-ppu-data-staging`, `bw-software-updates-staging`
- API Gateway: `bw-ppu-api-staging`

### Production Environment
- RDS: `bwppudb`
- EC2: `aurora-jump-server`, `insights_prod_backend`, `insights_prod_frontend`
- Lambda: `insert-ppu-data-dev-insert_ppu`, `generatePresignedUrl-v-1-9`, `generatePresignedUrl`, `presignedUrlForS3Upload`, `softwareUpdateHandler`, `sync_clock`
- DynamoDB: `event_log`, `sw_update`
- S3: `bw-tf-state-prod-us-east-2`, `bw-ppu-data`, `bw-software-updates`
- API Gateway: `bw-ppu-api`

## Configuration Options

### Verification Script Parameters

```bash
./scripts/verify-deployment.sh \
  --environment dev|staging|prod \
  --region us-east-2 \
  --config infra/live \
  --output verification-report.json \
  --wait-time 600  # Maximum wait time in seconds
```

### Retry Configuration

Each probe script includes configurable retry settings:
- **MAX_RETRIES**: Number of retry attempts (default: 6-10 per service)
- **RETRY_INTERVAL**: Wait time between retries (10-20 seconds)
- **EVENTUAL_CONSISTENCY_WAIT**: Initial wait for AWS consistency (30 seconds)

## Testing the Verification System

### Manual Testing

1. **Run verification locally**:
   ```bash
   # Ensure AWS CLI is configured with proper credentials
   aws sts get-caller-identity
   
   # Run verification for dev environment
   ./scripts/verify-deployment.sh --environment dev --region us-east-2
   ```

2. **Test individual probe scripts**:
   ```bash
   # Test RDS probe
   ./scripts/aws-resource-probes/rds-probe.sh --environment dev --region us-east-2 --expected-file /tmp/expected.json --results-file /tmp/results.json
   
   # Test EC2 probe
   ./scripts/aws-resource-probes/ec2-probe.sh --environment dev --region us-east-2 --expected-file /tmp/expected.json --results-file /tmp/results.json
   ```

### CI/CD Testing

1. **Test via PR comments**:
   - Create a PR with infrastructure changes
   - Comment `/digger apply dev` to trigger deployment with verification

2. **Monitor verification in Actions**:
   - Check GitHub Actions logs for verification output
   - Download verification report artifacts
   - Verify email notifications are received

## Troubleshooting

### Common Issues

1. **AWS CLI Access**: Ensure proper AWS credentials and permissions
2. **Resource Names**: Verify expected resource naming matches actual deployments
3. **SMTP Configuration**: Test email settings independently
4. **Eventual Consistency**: Increase wait times for slow-provisioning resources

### Debug Commands

```bash
# Check AWS credentials
aws sts get-caller-identity

# Test SMTP connectivity (requires telnet)
telnet smtp.gmail.com 587

# Verify script permissions
ls -la scripts/verify-deployment.sh scripts/aws-resource-probes/
```

### Logs and Monitoring

- **GitHub Actions Logs**: Full verification output with color-coded status
- **Verification Reports**: JSON artifacts with detailed resource information
- **Email Reports**: HTML-formatted summaries with resource breakdowns
- **PR Comments**: Real-time status updates with verification metrics

## Security Considerations

- **Secrets Management**: All sensitive information stored as GitHub secrets
- **AWS Permissions**: Uses existing environment-specific AWS credentials
- **Email Security**: SMTP credentials encrypted and not logged
- **Resource Access**: Read-only verification operations only

## Performance

- **Parallel Execution**: Multiple probe scripts run concurrently
- **Retry Logic**: Exponential backoff prevents excessive API calls
- **Timeout Protection**: Maximum wait times prevent hanging operations
- **Efficiency**: Early exit when resources are found

## Customization

To add new AWS services or modify resource expectations:

1. **Create new probe script** in `scripts/aws-resource-probes/`
2. **Update verification script** to include new probe
3. **Modify expected resources** in individual probe scripts
4. **Test thoroughly** with different environments

The system is designed to be modular and extensible for future AWS services and resource types.