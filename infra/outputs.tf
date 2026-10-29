output "authority" {
  value = "https://cognito-idp.us-east-1.amazonaws.com/${aws_cognito_user_pool.main.id}"
}

output "client_id" {
  value = aws_cognito_user_pool_client.web.id
}

output "cognito_domain" {
  value = "${var.domain_prefix}.auth.us-east-1.amazoncognito.com"
}

output "parser_url" {
  value = aws_lambda_function_url.parser.function_url
}

output "reports_bucket" {
  value = aws_s3_bucket.reports.id
}

output "queue_url" {
  value = aws_sqs_queue.requests.url
}

output "dlq_url" {
  value = aws_sqs_queue.requests_dlq.url
}

output "dkim_records" {
  description = "Add these three CNAME records at your DNS provider"
  value = [
    for t in aws_sesv2_email_identity.domain.dkim_signing_attributes[0].tokens :
    "${t}._domainkey.${var.domain} -> ${t}.dkim.amazonses.com"
  ]
}
