output "cluster_name" {
  description = "EKS cluster name."
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS Kubernetes API endpoint."
  value       = module.eks.cluster_endpoint
}

output "thanos_bucket_name" {
  description = "S3 bucket for Thanos blocks."
  value       = aws_s3_bucket.thanos.bucket
}

output "thanos_irsa_role_arn" {
  description = "IAM role ARN for the monitoring/thanos Kubernetes service account."
  value       = aws_iam_role.thanos.arn
}

output "tempo_bucket_name" {
  description = "S3 bucket for Tempo traces."
  value       = aws_s3_bucket.tempo.bucket
}

output "tempo_irsa_role_arn" {
  description = "IAM role ARN for the monitoring/tempo Kubernetes service account."
  value       = aws_iam_role.tempo.arn
}
