# Additional IAM Policy for Secrets Manager Access
# Add this to your existing iam.tf file

resource "aws_iam_policy" "healthcare_api_secrets_policy" {
  name        = "healthcare-api-secrets-policy"
  description = "IAM policy for accessing AWS Secrets Manager from healthcare API pods"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:poc-docker*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt"
        ]
        Resource = [
          "arn:aws:kms:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:key/*"
        ]
        Condition = {
          StringEquals = {
            "kms:ViaService" = "secretsmanager.${data.aws_region.current.name}.amazonaws.com"
          }
        }
      }
    ]
  })
  
  tags = {
    Environment = "production"
    Service     = "healthcare-prediction-api"
    Purpose     = "secrets-access"
  }
}

# Attach the secrets policy to the existing pod role
resource "aws_iam_role_policy_attachment" "healthcare_api_secrets_attachment" {
  role       = aws_iam_role.healthcare_api_pod_role.name
  policy_arn = aws_iam_policy.healthcare_api_secrets_policy.arn
}

# External Secrets Operator service account role
resource "aws_iam_role" "external_secrets_role" {
  name = "external-secrets-operator-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${var.eks_cluster_oidc_issuer_url}"
        }
        Condition = {
          StringEquals = {
            "${var.eks_cluster_oidc_issuer_url}:sub" = "system:serviceaccount:external-secrets-system:external-secrets"
            "${var.eks_cluster_oidc_issuer_url}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = {
    Environment = "production"
    Service     = "external-secrets-operator"
    Purpose     = "secrets-management"
  }
}

# Attach secrets policy to External Secrets Operator role
resource "aws_iam_role_policy_attachment" "external_secrets_attachment" {
  role       = aws_iam_role.external_secrets_role.name
  policy_arn = aws_iam_policy.healthcare_api_secrets_policy.arn
}

# Output the role ARNs for annotation in service accounts
output "healthcare_api_pod_role_arn" {
  description = "ARN of the IAM role for healthcare API pods"
  value       = aws_iam_role.healthcare_api_pod_role.arn
}

output "external_secrets_role_arn" {
  description = "ARN of the IAM role for External Secrets Operator"
  value       = aws_iam_role.external_secrets_role.arn
}