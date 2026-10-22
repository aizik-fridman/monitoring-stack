provider "aws" {
  region = var.region
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

locals {
  cluster_name = "${var.name}-${var.environment}"
  common_tags = merge(var.tags, {
    Project     = var.name
    Environment = var.environment
    ManagedBy   = "Terraform"
  })
  private_subnets = [
    for index, zone in slice(data.aws_availability_zones.available.names, 0, 3) :
    cidrsubnet(var.vpc_cidr, 4, index)
  ]
  public_subnets = [
    for index, zone in slice(data.aws_availability_zones.available.names, 0, 3) :
    cidrsubnet(var.vpc_cidr, 4, index + 8)
  ]
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name                 = local.cluster_name
  cidr                 = var.vpc_cidr
  azs                  = slice(data.aws_availability_zones.available.names, 0, 3)
  private_subnets      = local.private_subnets
  public_subnets       = local.public_subnets
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }

  tags = local.common_tags
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name                             = local.cluster_name
  cluster_version                          = var.kubernetes_version
  cluster_endpoint_public_access           = true
  cluster_endpoint_private_access          = true
  enable_cluster_creator_admin_permissions = true
  enable_irsa                              = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  eks_managed_node_groups = {
    observability = {
      name           = "observability"
      instance_types = ["m6i.large"]
      min_size       = 2
      max_size       = 6
      desired_size   = 3
      disk_size      = 100
    }
  }

  tags = local.common_tags
}

resource "aws_s3_bucket" "thanos" {
  bucket        = "${var.name}-${var.environment}-${data.aws_caller_identity.current.account_id}-thanos"
  force_destroy = false
  tags          = local.common_tags
}

resource "aws_s3_bucket" "tempo" {
  bucket        = "${var.name}-${var.environment}-${data.aws_caller_identity.current.account_id}-tempo"
  force_destroy = false
  tags          = local.common_tags
}

resource "aws_s3_bucket_versioning" "thanos" {
  bucket = aws_s3_bucket.thanos.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_versioning" "tempo" {
  bucket = aws_s3_bucket.tempo.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "thanos" {
  bucket = aws_s3_bucket.thanos.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tempo" {
  bucket = aws_s3_bucket.tempo.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "thanos" {
  bucket                  = aws_s3_bucket.thanos.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "tempo" {
  bucket                  = aws_s3_bucket.tempo.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "aws_iam_policy_document" "thanos_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"
    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:monitoring:thanos"]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "tempo_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"
    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:monitoring:tempo"]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "thanos" {
  name               = "${local.cluster_name}-thanos"
  assume_role_policy = data.aws_iam_policy_document.thanos_assume_role.json
  tags               = local.common_tags
}

resource "aws_iam_role" "tempo" {
  name               = "${local.cluster_name}-tempo"
  assume_role_policy = data.aws_iam_policy_document.tempo_assume_role.json
  tags               = local.common_tags
}

data "aws_iam_policy_document" "thanos_s3" {
  statement {
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.thanos.arn]
  }
  statement {
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
    ]
    resources = ["${aws_s3_bucket.thanos.arn}/*"]
  }
}

data "aws_iam_policy_document" "tempo_s3" {
  statement {
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.tempo.arn]
  }
  statement {
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
    ]
    resources = ["${aws_s3_bucket.tempo.arn}/*"]
  }
}

resource "aws_iam_role_policy" "thanos_s3" {
  name   = "thanos-object-storage"
  role   = aws_iam_role.thanos.id
  policy = data.aws_iam_policy_document.thanos_s3.json
}

resource "aws_iam_role_policy" "tempo_s3" {
  name   = "tempo-object-storage"
  role   = aws_iam_role.tempo.id
  policy = data.aws_iam_policy_document.tempo_s3.json
}
