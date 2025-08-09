terraform {
  required_providers { aws = { source = "hashicorp/aws", version = ">= 5.0" } }
}
provider "aws" { region = var.region }
locals { bucket_name = "${var.bucket_prefix}-${var.env}-${var.region}"  table_name = "${var.dynamodb_table_prefix}-${var.env}" }
# S3 bucket with KMS (AWS-managed key) and strict policies
data "aws_kms_key" "s3" { key_id = "alias/aws/s3" }
resource "aws_s3_bucket" "state" { bucket = local.bucket_name  force_destroy = false  tags = merge(var.tags, { Environment = var.env, ManagedBy = "bootstrap" }) }
resource "aws_s3_bucket_public_access_block" "state" { bucket = aws_s3_bucket.state.id block_public_acls=true block_public_policy=true ignore_public_acls=true restrict_public_buckets=true }
resource "aws_s3_bucket_versioning" "state" { bucket = aws_s3_bucket.state.id versioning_configuration { status = "Enabled" } }
resource "aws_s3_bucket_server_side_encryption_configuration" "state" { bucket = aws_s3_bucket.state.id rule { apply_server_side_encryption_by_default { sse_algorithm = "aws:kms" kms_master_key_id = data.aws_kms_key.s3.arn } } }
resource "aws_s3_bucket_policy" "state_secure" {
  bucket = aws_s3_bucket.state.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      { Sid: "RequireTLS", Effect: "Deny", Principal: "*", Action: "s3:*", Resource: [aws_s3_bucket.state.arn, "${aws_s3_bucket.state.arn}/*"], Condition: { Bool: { "aws:SecureTransport": false } } },
      { Sid: "RequireKMSEncryption", Effect: "Deny", Principal: "*", Action: "s3:PutObject", Resource: "${aws_s3_bucket.state.arn}/*", Condition: { StringNotEquals: { "s3:x-amz-server-side-encryption": "aws:kms" } } }
    ]
  })
}
# DynamoDB locks with PITR
resource "aws_dynamodb_table" "locks" { name = local.table_name billing_mode = "PAY_PER_REQUEST" hash_key = "LockID" attribute { name = "LockID" type = "S" } tags = merge(var.tags, { Environment = var.env, ManagedBy = "bootstrap" }) }
resource "aws_dynamodb_table_point_in_time_recovery" "locks_pitr" { table_name = aws_dynamodb_table.locks.name point_in_time_recovery_enabled = true }