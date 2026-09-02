output "state_bucket_name" {
  description = "Nombre del bucket — usar en backend config de aws/ y cloudflare/"
  value       = aws_s3_bucket.tf_state.id
}

output "state_bucket_arn" {
  description = "ARN del bucket"
  value       = aws_s3_bucket.tf_state.arn
}
