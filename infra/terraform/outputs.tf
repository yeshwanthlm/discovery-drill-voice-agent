output "dynamodb_table_name" {
  value = aws_dynamodb_table.sessions.name
}

output "cognito_user_pool_id" {
  value = aws_cognito_user_pool.pool.id
}

output "cognito_client_id" {
  value = aws_cognito_user_pool_client.client.id
}

output "cognito_hosted_ui_domain" {
  value = "https://${aws_cognito_user_pool_domain.domain.domain}.auth.${var.aws_region}.amazoncognito.com"
}

output "frontend_url" {
  description = "Your live, auth-gated Ready Check frontend"
  value       = local.frontend_url
}

output "cloudfront_domain" {
  description = "Raw CloudFront domain (use frontend_url instead)"
  value       = aws_cloudfront_distribution.frontend.domain_name
}

output "next_manual_step" {
  value = "No manual step needed — 3 users were created automatically (see cognito_test_accounts output). Each is in FORCE_CHANGE_PASSWORD state, so the first Hosted UI login for each will prompt to set a real password."
}

output "cognito_test_accounts" {
  description = "Accounts created automatically, and the shared temporary password for first login"
  value = {
    accounts            = [var.admin_email, "alex.dummy@example.com", "sam.example@example.com"]
    temporary_password  = "TempPass123!"
  }
}

output "get_session_history_url" {
  description = "Function URL for the get-session-history Lambda"
  value       = aws_lambda_function_url.get_session_history_url.function_url
}

output "log_debrief_url" {
  description = "Function URL for the log-debrief Lambda"
  value       = aws_lambda_function_url.log_debrief_url.function_url
}
