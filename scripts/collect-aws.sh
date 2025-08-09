#!/usr/bin/env bash
# collect-aws.v3.2.sh — macOS-safe (no associative arrays), resilient, env-gated
# Usage:
#   ./collect-aws.v3.2.sh <env> [service]
#     env: dev|staging|prod
#     service (optional): rds|dynamodb|s3|ec2|apigw|lambda|network|all
set -euox pipefail

ENV="${1:-}"
SVC="${2:-all}"
REGION="us-east-2"

if [[ -z "${ENV}" ]]; then
  echo "Usage: $0 <env> [service]" >&2
  exit 1
fi

case "$ENV" in
  dev)     AWS_PROFILE="bwamazondev";      ACCOUNT_ID="824357028182" ;;
  staging) AWS_PROFILE="bwamazonstaging";  ACCOUNT_ID="574210586915" ;;
  prod)    AWS_PROFILE="bwamazonprod";     ACCOUNT_ID="154948530138" ;;
  *) echo "env must be one of: dev|staging|prod" >&2; exit 1 ;;
esac

export AWS_PROFILE
aws --version >/dev/null || { echo "AWS CLI not found"; exit 1; }

# Preflight: confirm account
ACTUAL=$(aws sts get-caller-identity --query Account --output text)
if [[ "$ACTUAL" != "$ACCOUNT_ID" ]]; then
  echo "FATAL: Wrong AWS account. Expected $ACCOUNT_ID, got $ACTUAL" >&2
  exit 2
fi

# Output base
BASE="exports/${ENV}"
mkdir -p "$BASE"

# Inventory (from your list)
RDS_INSTANCES_DEV=( "bwppudb" )
RDS_CLUSTERS_DEV=( "db-aurora-1" )
RDS_INSTANCES_STAGING=( "bwppudb" )
RDS_CLUSTERS_STAGING=( "db-aurora-1" )
RDS_INSTANCES_PROD=( "bwppudb" )
RDS_CLUSTERS_PROD=( "insight-production-db" )

DDB_TABLES=( "event_log" "sw_update" )
S3_BUCKETS=( "steventlogs" "stsoftwareupdate" )

EC2_NAMES_DEV=( "aurora-jump-server" "insights_dev_backend" "insights_dev_frontend" )
EC2_NAMES_STAGING=( "aurora-jump-server" "insights_staging_backend" "insights_staging_frontend" )
EC2_NAMES_PROD=( "aurora-jump-server" "insights_prod_backend" "insights_prod_frontend" )

APIGW_IDS=( "ndk8t3b961" "j1w31ky0s3" "pixwwabvy7" "626pn9jbxh" "lc0kt8b3p5" "9553ewljh9" )

LAMBDA_DEV=(
  "generatePresignedUrl-v-1-8"
  "softwareUpdateHandler"
  "presignedUrlForS3Upload"
  "insert-ppu-data-dev-insert_ppu"
  "sync_clock"
  "generatePresignedUrl"
)
LAMBDA_STAGING=(
  "generatePresignedUrl-v-1-8"
  "softwareUpdateHandler"
  "presignedUrlForS3Upload"
  "insert-ppu-data-dev-insert_ppu"
  "sync_clock"
  "generatePresignedUrl"
)
LAMBDA_PROD=(
  "generatePresignedUrl-v-1-9"
  "softwareUpdateHandler"
  "presignedUrlForS3Upload"
  "insert-ppu-data-dev-insert_ppu"
  "sync_clock"
  "generatePresignedUrl"
)

DEFAULT_VPC_ID="vpc-d2a9d9bb"
VPC_ID="${VPC_ID:-$DEFAULT_VPC_ID}"

json_save() {
  local path="$1"
  local tmp
  tmp="$(mktemp)"
  mkdir -p "$(dirname "$path")"
  cat > "$tmp" || true
  if [[ -s "$tmp" ]]; then
    mv "$tmp" "$path"
  else
    echo '{}' > "$path"
    rm -f "$tmp"
  fi
}

aws_to_file() {
  local file="$1"; shift
  local _json
  if _json="$(aws "$@" --output json 2>/dev/null)"; then
    printf "%s" "$_json" | json_save "$file"
  else
    echo "{}" > "$file"
  fi
}

collect_rds() {
  local outdir="${BASE}/rds"
  mkdir -p "$outdir"
  local insts=() clus=()
  case "$ENV" in
    dev)     insts=("${RDS_INSTANCES_DEV[@]}"); clus=("${RDS_CLUSTERS_DEV[@]}");;
    staging) insts=("${RDS_INSTANCES_STAGING[@]}"); clus=("${RDS_CLUSTERS_STAGING[@]}");;
    prod)    insts=("${RDS_INSTANCES_PROD[@]}"); clus=("${RDS_CLUSTERS_PROD[@]}");;
  esac

  local id dir
  for id in "${insts[@]}"; do
    dir="${outdir}/${id}"; mkdir -p "$dir"
    aws_to_file "${dir}/instance.json" rds describe-db-instances --db-instance-identifier "$id" --region "$REGION"
    aws_to_file "${dir}/tags.json"     rds list-tags-for-resource --resource-name "arn:aws:rds:${REGION}:${ACCOUNT_ID}:db:${id}"
  done

  local cid
  for cid in "${clus[@]}"; do
    dir="${outdir}/${cid}"; mkdir -p "$dir"
    aws_to_file "${dir}/cluster.json" rds describe-db-clusters --db-cluster-identifier "$cid" --region "$REGION"
    aws_to_file "${dir}/tags.json"    rds list-tags-for-resource --resource-name "arn:aws:rds:${REGION}:${ACCOUNT_ID}:cluster:${cid}"
  done

  aws_to_file "${outdir}/db-subnet-group-default.json" rds describe-db-subnet-groups --db-subnet-group-name default --region "$REGION"
}

collect_dynamodb() {
  local outdir="${BASE}/dynamodb"; mkdir -p "$outdir"
  local t dir
  for t in "${DDB_TABLES[@]}"; do
    dir="${outdir}/${t}"; mkdir -p "$dir"
    aws_to_file "${dir}/table.json"  dynamodb describe-table --table-name "$t" --region "$REGION"
    aws_to_file "${dir}/pitr.json"   dynamodb describe-continuous-backups --table-name "$t" --region "$REGION"
    aws_to_file "${dir}/ttl.json"    dynamodb describe-time-to-live --table-name "$t" --region "$REGION"
    aws_to_file "${dir}/tags.json"   dynamodb list-tags-of-resource --resource-arn "arn:aws:dynamodb:${REGION}:${ACCOUNT_ID}:table/${t}" --region "$REGION"
  done
}

collect_s3() {
  local outdir="${BASE}/s3"; mkdir -p "$outdir"
  local b dir
  for b in "${S3_BUCKETS[@]}"; do
    dir="${outdir}/${b}"; mkdir -p "$dir"
    aws_to_file "${dir}/location.json"      s3api get-bucket-location --bucket "$b" --region "$REGION"
    aws_to_file "${dir}/encryption.json"    s3api get-bucket-encryption --bucket "$b" --region "$REGION"
    aws_to_file "${dir}/versioning.json"    s3api get-bucket-versioning --bucket "$b" --region "$REGION"
    aws_to_file "${dir}/public-access.json" s3api get-public-access-block --bucket "$b" --region "$REGION"
    aws_to_file "${dir}/policy.json"        s3api get-bucket-policy --bucket "$b" --region "$REGION"
    aws_to_file "${dir}/cors.json"          s3api get-bucket-cors --bucket "$b" --region "$REGION"
    aws_to_file "${dir}/lifecycle.json"     s3api get-bucket-lifecycle-configuration --bucket "$b" --region "$REGION"
    aws_to_file "${dir}/logging.json"       s3api get-bucket-logging --bucket "$b" --region "$REGION"
    aws_to_file "${dir}/tags.json"          s3api get-bucket-tagging --bucket "$b" --region "$REGION"
  done
}

collect_ec2() {
  local outdir="${BASE}/ec2"; mkdir -p "$outdir"
  local names=()
  case "$ENV" in
    dev) names=("${EC2_NAMES_DEV[@]}");;
    staging) names=("${EC2_NAMES_STAGING[@]}");;
    prod) names=("${EC2_NAMES_PROD[@]}");;
  esac
  local name dir
  for name in "${names[@]}"; do
    dir="${outdir}/${name}"; mkdir -p "$dir"
    aws_to_file "${dir}/instance.json" ec2 describe-instances --region "$REGION" --filters "Name=tag:Name,Values=${name}"
  done
}

collect_apigw() {
  local outdir="${BASE}/apigw-rest"; mkdir -p "$outdir"
  local id dir
  for id in "${APIGW_IDS[@]}"; do
    dir="${outdir}/${id}"; mkdir -p "$dir"
    aws_to_file "${dir}/api.json"          apigateway get-rest-api --rest-api-id "$id" --region "$REGION"
    aws_to_file "${dir}/stages.json"       apigateway get-stages --rest-api-id "$id" --region "$REGION"
    aws_to_file "${dir}/resources.json"    apigateway get-resources --rest-api-id "$id" --region "$REGION"
    aws_to_file "${dir}/authorizers.json"  apigateway get-authorizers --rest-api-id "$id" --region "$REGION"
    aws_to_file "${dir}/deployments.json"  apigateway get-deployments --rest-api-id "$id" --region "$REGION"
    aws_to_file "${dir}/domain-names.json" apigateway get-domain-names --region "$REGION"
  done
}

collect_lambda() {
  local outdir="${BASE}/lambda"; mkdir -p "$outdir"
  local names=()
  case "$ENV" in
    dev) names=("${LAMBDA_DEV[@]}");;
    staging) names=("${LAMBDA_STAGING[@]}");; 
    prod) names=("${LAMBDA_PROD[@]}");;
  esac
  local fn dir
  for fn in "${names[@]}"; do
    dir="${outdir}/${fn}"; mkdir -p "$dir"
    aws_to_file "${dir}/function.json"       lambda get-function --function-name "$fn" --region "$REGION"
    aws_to_file "${dir}/configuration.json"  lambda get-function-configuration --function-name "$fn" --region "$REGION"
    aws_to_file "${dir}/policy.json"         lambda get-policy --function-name "$fn" --region "$REGION"
    aws_to_file "${dir}/url.json"            lambda get-function-url-config --function-name "$fn" --region "$REGION"
    aws_to_file "${dir}/aliases.json"        lambda list-aliases --function-name "$fn" --region "$REGION"
    aws_to_file "${dir}/event-source-mappings.json" lambda list-event-source-mappings --function-name "$fn" --region "$REGION"
  done
}

discover_sgs_for_vpc() {
  aws ec2 describe-security-groups --filters "Name=vpc-id,Values=${VPC_ID}" --region "$REGION"     --query "SecurityGroups[].GroupId" --output text 2>/dev/null || true
}

discover_sgs_for_rds() {
  local insts=() clus=()
  case "$ENV" in
    dev)     insts=("${RDS_INSTANCES_DEV[@]}"); clus=("${RDS_CLUSTERS_DEV[@]}");;
    staging) insts=("${RDS_INSTANCES_STAGING[@]}"); clus=("${RDS_CLUSTERS_STAGING[@]}");;
    prod)    insts=("${RDS_INSTANCES_PROD[@]}"); clus=("${RDS_CLUSTERS_PROD[@]}");;
  esac
  local ids
  for id in "${insts[@]}"; do
    ids=$(aws rds describe-db-instances --db-instance-identifier "$id" --region "$REGION"       --query "DBInstances[].VpcSecurityGroups[].VpcSecurityGroupId" --output text 2>/dev/null || true)
    [[ -n "$ids" ]] && echo "$ids"
  done
  for cid in "${clus[@]}"; do
    ids=$(aws rds describe-db-clusters --db-cluster-identifier "$cid" --region "$REGION"       --query "DBClusters[].VpcSecurityGroups[].VpcSecurityGroupId" --output text 2>/dev/null || true)
    [[ -n "$ids" ]] && echo "$ids"
  done
}

collect_network() {
  local outdir="${BASE}/network"; mkdir -p "$outdir"
  aws_to_file "${outdir}/vpc.json"            ec2 describe-vpcs --vpc-ids "$VPC_ID" --region "$REGION"
  aws_to_file "${outdir}/subnets.json"        ec2 describe-subnets --filters "Name=vpc-id,Values=${VPC_ID}" --region "$REGION"
  aws_to_file "${outdir}/route-tables.json"   ec2 describe-route-tables --filters "Name=vpc-id,Values=${VPC_ID}" --region "$REGION"
  aws_to_file "${outdir}/igw.json"            ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=${VPC_ID}" --region "$REGION"
  aws_to_file "${outdir}/nat-gateways.json"   ec2 describe-nat-gateways --filter "Name=vpc-id,Values=${VPC_ID}" --region "$REGION"
  aws_to_file "${outdir}/vpc-endpoints.json"  ec2 describe-vpc-endpoints --filters "Name=vpc-id,Values=${VPC_ID}" --region "$REGION"
  aws_to_file "${outdir}/flow-logs.json"      ec2 describe-flow-logs --filter "Name=resource-id,Values=${VPC_ID}" --region "$REGION"

  # Discover SGs and uniq them without Bash 4 associative arrays
  sg_all="$(printf "%s
" "$(discover_sgs_for_vpc)" "$(discover_sgs_for_rds)" | tr '[:space:]' '\n' | sed '/^$/d' | sort -u)"
  if [[ -n "$sg_all" ]]; then
    while IFS= read -r sg; do
      aws_to_file "${outdir}/sg-${sg}.json" ec2 describe-security-groups --group-ids "$sg" --region "$REGION"
    done <<< "$sg_all"
  fi
}

run() {
  case "$SVC" in
    rds)      collect_rds ;;
    dynamodb) collect_dynamodb ;;
    s3)       collect_s3 ;;
    ec2)      collect_ec2 ;;
    apigw)    collect_apigw ;;
    lambda)   collect_lambda ;;
    network)  collect_network ;;
    all)      collect_network; collect_rds; collect_dynamodb; collect_s3; collect_ec2; collect_apigw; collect_lambda ;;
    *) echo "unknown service: $SVC" >&2; exit 3 ;;
  esac
  echo "Done. See ${BASE}/ for outputs."
}

run
