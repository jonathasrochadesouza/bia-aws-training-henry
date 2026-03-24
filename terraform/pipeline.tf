################################################################################
# Pipeline CI/CD - CodePipeline + CodeBuild
#
# Fluxo:
#   GitHub (push) → CodePipeline → CodeBuild (build + push ECR) → ECS Deploy
#
# Variáveis necessárias antes do apply:
#   - var.github_owner        : usuário/org do GitHub
#   - var.github_repo         : nome do repositório
#   - var.github_branch       : branch a monitorar (ex: main)
#   - var.github_oauth_token  : token OAuth do GitHub (sensitive)
################################################################################

# ── S3 Bucket para artefatos do pipeline ─────────────────────────────────────

resource "aws_s3_bucket" "pipeline_artifacts" {
  bucket        = "bia-pipeline-artifacts-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
}

data "aws_caller_identity" "current" {}

# ── IAM Role para o CodePipeline ─────────────────────────────────────────────

resource "aws_iam_role" "codepipeline_role" {
  name = "bia-codepipeline-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "codepipeline.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "codepipeline_policy" {
  name = "bia-codepipeline-policy"
  role = aws_iam_role.codepipeline_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:GetBucketVersioning"]
        Resource = ["${aws_s3_bucket.pipeline_artifacts.arn}", "${aws_s3_bucket.pipeline_artifacts.arn}/*"]
      },
      {
        Effect   = "Allow"
        Action   = ["codebuild:BatchGetBuilds", "codebuild:StartBuild"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["ecs:DescribeServices", "ecs:DescribeTaskDefinition", "ecs:DescribeTasks",
                    "ecs:ListTasks", "ecs:RegisterTaskDefinition", "ecs:UpdateService"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["iam:PassRole"]
        Resource = "*"
      }
    ]
  })
}

# ── IAM Role para o CodeBuild ─────────────────────────────────────────────────

resource "aws_iam_role" "codebuild_role" {
  name = "bia-codebuild-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "codebuild.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "codebuild_policy" {
  name = "bia-codebuild-policy"
  role = aws_iam_role.codebuild_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # Logs no CloudWatch
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "*"
      },
      {
        # Acesso ao S3 de artefatos
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:GetBucketVersioning"]
        Resource = ["${aws_s3_bucket.pipeline_artifacts.arn}", "${aws_s3_bucket.pipeline_artifacts.arn}/*"]
      },
      {
        # Push/pull de imagens no ECR
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken", "ecr:BatchCheckLayerAvailability",
                    "ecr:GetDownloadUrlForLayer", "ecr:BatchGetImage",
                    "ecr:InitiateLayerUpload", "ecr:UploadLayerPart",
                    "ecr:CompleteLayerUpload", "ecr:PutImage"]
        Resource = "*"
      }
    ]
  })
}

# ── CodeBuild Project ─────────────────────────────────────────────────────────
# Executa o buildspec.yml na raiz do projeto
# Build: docker build → docker push ECR → gera imagedefinitions.json

resource "aws_codebuild_project" "bia" {
  name          = "bia-build"
  description   = "Build da imagem Docker da BIA e push para o ECR"
  service_role  = aws_iam_role.codebuild_role.arn
  build_timeout = 20 # minutos

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:7.0"
    type                        = "LINUX_CONTAINER"
    privileged_mode             = true # necessário para docker build
    image_pull_credentials_type = "CODEBUILD"
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspec.yml" # arquivo na raiz do repositório
  }

  logs_config {
    cloudwatch_logs {
      group_name  = "/codebuild/bia"
      stream_name = "build"
    }
  }
}

# ── CodePipeline ──────────────────────────────────────────────────────────────
# Stage 1: Source  — GitHub via webhook
# Stage 2: Build   — CodeBuild (docker build + push ECR)
# Stage 3: Deploy  — ECS rolling update com imagedefinitions.json

resource "aws_codepipeline" "bia" {
  name     = "bia-prod"
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.pipeline_artifacts.bucket
    type     = "S3"
  }

  # Stage 1: Source — GitHub
  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "ThirdParty"
      provider         = "GitHub"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        Owner      = var.github_owner
        Repo       = var.github_repo
        Branch     = var.github_branch
        OAuthToken = var.github_oauth_token
      }
    }
  }

  # Stage 2: Build — CodeBuild
  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]

      configuration = {
        ProjectName = aws_codebuild_project.bia.name
      }
    }
  }

  # Stage 3: Deploy — ECS (usa imagedefinitions.json gerado pelo buildspec)
  stage {
    name = "Deploy"

    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "ECS"
      version         = "1"
      input_artifacts = ["build_output"]

      configuration = {
        ClusterName = aws_ecs_cluster.bia_alb.name
        ServiceName = aws_ecs_service.bia_alb_prod.name
        FileName    = "imagedefinitions.json"
      }
    }
  }
}
