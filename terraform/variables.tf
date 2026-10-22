variable "region" {
  description = "AWS region for the EKS cluster and observability buckets."
  type        = string
  default     = "us-east-1"
}

variable "name" {
  description = "Short prefix for AWS resources."
  type        = string
  default     = "observability"
}

variable "environment" {
  description = "Environment name used in resource names and tags."
  type        = string
  default     = "production"
}

variable "kubernetes_version" {
  description = "EKS Kubernetes minor version supported by the selected EKS module."
  type        = string
  default     = "1.32"
}

variable "vpc_cidr" {
  description = "CIDR range for the EKS VPC."
  type        = string
  default     = "10.40.0.0/16"
}

variable "tags" {
  description = "Additional tags applied to managed resources."
  type        = map(string)
  default     = {}
}
