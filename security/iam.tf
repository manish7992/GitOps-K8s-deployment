# Terraform configuration for AWS IAM roles and policies
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.0"
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# IAM role for EKS pods (IRSA - IAM Roles for Service Accounts)
resource "aws_iam_role" "healthcare_api_pod_role" {
  name = "healthcare-api-pod-role"

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
            "${var.eks_cluster_oidc_issuer_url}:sub" = "system:serviceaccount:healthcare-api:healthcare-api-sa"
            "${var.eks_cluster_oidc_issuer_url}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = {
    Environment = "production"
    Service     = "healthcare-prediction-api"
    Purpose     = "pod-execution"
  }
}

# IAM policy for healthcare API pods
resource "aws_iam_policy" "healthcare_api_pod_policy" {
  name        = "healthcare-api-pod-policy"
  description = "IAM policy for healthcare prediction API pods"

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
          "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:healthcare-api/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ]
        Resource = [
          "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/healthcare-api/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "cloudwatch:namespace" = ["Healthcare/API", "Healthcare/EKS"]
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = [
          "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/healthcare/api/*"
        ]
      }
    ]
  })
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "healthcare_api_pod_policy_attachment" {
  role       = aws_iam_role.healthcare_api_pod_role.name
  policy_arn = aws_iam_policy.healthcare_api_pod_policy.arn
}

# IAM role for CI/CD (GitHub Actions)
resource "aws_iam_role" "healthcare_api_cicd_role" {
  name = "healthcare-api-cicd-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_repository}:*"
          }
        }
      }
    ]
  })

  tags = {
    Environment = "production"
    Service     = "healthcare-prediction-api"
    Purpose     = "ci-cd"
  }
}

# IAM policy for CI/CD operations
resource "aws_iam_policy" "healthcare_api_cicd_policy" {
  name        = "healthcare-api-cicd-policy"
  description = "IAM policy for healthcare API CI/CD operations"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
        Resource = [
          "arn:aws:ecr:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:repository/healthcare-prediction-api"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters"
        ]
        Resource = [
          "arn:aws:eks:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:cluster/healthcare-cluster"
        ]
      }
    ]
  })
}

# Attach CI/CD policy to role
resource "aws_iam_role_policy_attachment" "healthcare_api_cicd_policy_attachment" {
  role       = aws_iam_role.healthcare_api_cicd_role.name
  policy_arn = aws_iam_policy.healthcare_api_cicd_policy.arn
}

# Secrets Manager secrets
resource "aws_secretsmanager_secret" "healthcare_api_secrets" {
  name        = "healthcare-api/production"
  description = "Secrets for healthcare prediction API production environment"

  recovery_window_in_days = 7

  tags = {
    Environment = "production"
    Service     = "healthcare-prediction-api"
  }
}

resource "aws_secretsmanager_secret_version" "healthcare_api_secrets_version" {
  secret_id = aws_secretsmanager_secret.healthcare_api_secrets.id
  secret_string = jsonencode({
    database_url = "postgresql://user:password@healthcare-db.internal:5432/healthcare"
    api_key      = "your-secure-api-key-here"
    jwt_secret   = "your-jwt-secret-key-here"
  })
}

# Variables
variable "eks_cluster_oidc_issuer_url" {
  description = "EKS cluster OIDC issuer URL"
  type        = string
}

variable "github_repository" {
  description = "GitHub repository for CI/CD"
  type        = string
  default     = "healthcare-org/healthcare-prediction-api"
}

# Outputs
output "healthcare_api_pod_role_arn" {
  description = "ARN of the IAM role for healthcare API pods"
  value       = aws_iam_role.healthcare_api_pod_role.arn
}

output "healthcare_api_cicd_role_arn" {
  description = "ARN of the IAM role for CI/CD"
  value       = aws_iam_role.healthcare_api_cicd_role.arn
}