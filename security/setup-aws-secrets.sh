#!/bin/bash

# AWS Secrets Manager setup for Docker Hub credentials
# Run these commands to create the secret in AWS Secrets Manager

# Set variables
SECRET_NAME="poc-docker"
REGION="us-west-2"
DOCKERHUB_USERNAME="manish8757"
# Use environment variable if set, otherwise use placeholder
DOCKERHUB_TOKEN="${DOCKERHUB_TOKEN:-REPLACE_WITH_YOUR_TOKEN}"

echo "Creating Docker Hub credentials secret in AWS Secrets Manager..."

# Check if token is still placeholder
if [ "$DOCKERHUB_TOKEN" = "REPLACE_WITH_YOUR_TOKEN" ]; then
    echo "ERROR: Please set your Docker Hub access token"
    echo "Run with: DOCKERHUB_TOKEN=your_token ./setup-aws-secrets.sh"
    exit 1
fi

# Create the secret in AWS Secrets Manager
aws secretsmanager create-secret \
    --name "$SECRET_NAME" \
    --description "Docker Hub credentials for healthcare prediction API" \
    --region "$REGION" \
    --secret-string "{
        \"username\": \"$DOCKERHUB_USERNAME\",
        \"password\": \"$DOCKERHUB_TOKEN\"
    }"

echo "Secret created successfully!"
echo "Secret ARN: arn:aws:secretsmanager:$REGION:$(aws sts get-caller-identity --query Account --output text):secret:$SECRET_NAME"

echo ""
echo "Next steps:"
echo "1. Make sure your EKS service account has permissions to read this secret"
echo "2. Apply the external secret configuration: kubectl apply -f security/dockerhub-external-secret.yaml"