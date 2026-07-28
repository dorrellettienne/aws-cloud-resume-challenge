output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID used for cache invalidations."
  value       = aws_cloudfront_distribution.resume.id
}

output "counter_url" {
  description = "Public Lambda Function URL for the visitor counter."
  value       = aws_lambda_function_url.visitor_counter.function_url
}

output "resume_bucket_name" {
  description = "Private S3 bucket that stores the resume site."
  value       = aws_s3_bucket.resume.id
}

output "site_url" {
  description = "CloudFront URL for the deployed resume."
  value       = "https://${aws_cloudfront_distribution.resume.domain_name}"
}
