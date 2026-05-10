#!/usr/bin/env bash
# bootstrap-tfstate.sh
# Run this ONCE before the first `terraform init`
# Creates the S3 bucket and DynamoDB table used for remote Terraform state.

set -euo pipefail

REGION="${AWS_REGION:-us-east-1}"
BUCKET_NAME="${TF_STATE_BUCKET:-devops-challenge-tfstate}"
DYNAMO_TABLE="${TF_LOCK_TABLE:-devops-challenge-tfstate-lock}"

echo "==> Creating S3 bucket: $BUCKET_NAME in $REGION"
if [ "$REGION" = "us-east-1" ]; then
  aws s3api create-bucket \
    --bucket "$BUCKET_NAME" \
    --region "$REGION"
else
  aws s3api create-bucket \
    --bucket "$BUCKET_NAME" \
    --region "$REGION" \
    --create-bucket-configuration LocationConstraint="$REGION"
fi

echo "==> Enabling versioning on $BUCKET_NAME"
aws s3api put-bucket-versioning \
  --bucket "$BUCKET_NAME" \
  --versioning-configuration Status=Enabled

echo "==> Enabling encryption on $BUCKET_NAME"
aws s3api put-bucket-encryption \
  --bucket "$BUCKET_NAME" \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

echo "==> Blocking public access on $BUCKET_NAME"
aws s3api put-public-access-block \
  --bucket "$BUCKET_NAME" \
  --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

echo "==> Creating DynamoDB table: $DYNAMO_TABLE"
aws dynamodb create-table \
  --table-name "$DYNAMO_TABLE" \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region "$REGION" 2>/dev/null || echo "  Table already exists, skipping."

echo ""
echo "✅ Terraform backend ready!"
echo "   Bucket : $BUCKET_NAME"
echo "   Table  : $DYNAMO_TABLE"
echo "   Region : $REGION"
echo ""
echo "Now run: cd terraform && terraform init"
