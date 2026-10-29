resource "aws_cognito_user_pool" "main" {
  provider = aws.us_east_1

  name                     = "${var.project_name}-users"
  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]
  user_pool_tier           = "ESSENTIALS"

  admin_create_user_config {
    allow_admin_create_user_only = false
  }

  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_uppercase = true
    require_numbers   = true
    require_symbols   = false
  }

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }
}

resource "aws_cognito_identity_provider" "google" {
  provider = aws.us_east_1

  user_pool_id  = aws_cognito_user_pool.main.id
  provider_name = "Google"
  provider_type = "Google"

  provider_details = {
    client_id        = var.google_client_id
    client_secret    = var.google_client_secret
    authorize_scopes = "openid email profile"
    # filled in by Cognito for the Google provider; spelled out so the plan stays empty
    attributes_url                = "https://people.googleapis.com/v1/people/me?personFields="
    attributes_url_add_attributes = "true"
    authorize_url                 = "https://accounts.google.com/o/oauth2/v2/auth"
    oidc_issuer                   = "https://accounts.google.com"
    token_request_method          = "POST"
    token_url                     = "https://www.googleapis.com/oauth2/v4/token"
  }

  attribute_mapping = {
    email          = "email"
    email_verified = "email_verified"
    username       = "sub"
  }
}

resource "aws_cognito_user_pool_client" "web" {
  provider   = aws.us_east_1
  depends_on = [aws_cognito_identity_provider.google]

  user_pool_id                         = aws_cognito_user_pool.main.id
  name                                 = "${var.project_name}-web"
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes                 = ["openid", "email", "profile"]
  supported_identity_providers         = ["COGNITO", "Google"]
  callback_urls                        = [var.site_url, var.local_url]
  logout_urls                          = [var.site_url, var.local_url]
}

resource "aws_cognito_user_pool_domain" "main" {
  provider = aws.us_east_1

  user_pool_id          = aws_cognito_user_pool.main.id
  domain                = var.domain_prefix
  managed_login_version = 2
}

resource "aws_cognito_managed_login_branding" "web" {
  provider   = aws.us_east_1
  depends_on = [aws_cognito_user_pool_domain.main]

  user_pool_id                = aws_cognito_user_pool.main.id
  client_id                   = aws_cognito_user_pool_client.web.id
  use_cognito_provided_values = true
}
