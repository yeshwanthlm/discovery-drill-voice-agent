# ---------- Cognito User Pool ----------
resource "aws_cognito_user_pool" "pool" {
  name = "${var.function_name}-users"

  username_attributes     = ["email"]
  auto_verified_attributes = ["email"]

  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = true
    require_symbols   = false
    require_uppercase = true
  }

  schema {
    name                = "email"
    attribute_data_type = "String"
    required            = true
    mutable             = true
  }

  schema {
    name                = "given_name"
    attribute_data_type = "String"
    required            = true
    mutable             = true
  }
}

# ---------- App Client — public client, no secret, implicit flow ----------
# NOTE: implicit flow (response_type=token) is used for simplicity, since
# there's no backend token-exchange endpoint in this frontend. A
# production version should migrate to Authorization Code + PKCE.
resource "aws_cognito_user_pool_client" "client" {
  name         = "${var.function_name}-frontend"
  user_pool_id = aws_cognito_user_pool.pool.id

  generate_secret = false

  allowed_oauth_flows                 = ["implicit"]
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_scopes                = ["openid", "email", "profile"]

  callback_urls = [local.frontend_url]
  logout_urls   = [local.frontend_url]

  supported_identity_providers = ["COGNITO"]
}

# ---------- Hosted UI domain ----------
resource "aws_cognito_user_pool_domain" "domain" {
  domain       = var.cognito_domain_prefix
  user_pool_id = aws_cognito_user_pool.pool.id
}

# ---------- Users ----------
# NOTE: `aws_cognito_user` creates the account in FORCE_CHANGE_PASSWORD
# state — on first Hosted UI login, each user will be prompted to set a
# real password themselves. This is normal Cognito behavior, not a bug.
# The temporary password below is shared/known deliberately since these
# are demo accounts, not real production credentials.

locals {
  temporary_password = "TempPass123!"
}

resource "aws_cognito_user" "admin" {
  user_pool_id     = aws_cognito_user_pool.pool.id
  username         = var.admin_email
  temporary_password = local.temporary_password

  attributes = {
    email          = var.admin_email
    email_verified = "true"
    given_name     = var.admin_given_name
  }
}

# Two example/dummy accounts, using the reserved example.com domain
# (RFC 2606) so nothing ever actually gets emailed to a real address.
resource "aws_cognito_user" "dummy_one" {
  user_pool_id     = aws_cognito_user_pool.pool.id
  username         = "alex.dummy@example.com"
  temporary_password = local.temporary_password

  attributes = {
    email          = "alex.dummy@example.com"
    email_verified = "true"
    given_name     = "Alex"
  }
}

resource "aws_cognito_user" "dummy_two" {
  user_pool_id     = aws_cognito_user_pool.pool.id
  username         = "sam.example@example.com"
  temporary_password = local.temporary_password

  attributes = {
    email          = "sam.example@example.com"
    email_verified = "true"
    given_name     = "Sam"
  }
}
