# ---------- Predictable frontend URL — custom domain via CloudFront ----------
locals {
  frontend_url = "https://discover.thefdeguy.com"
}

# ---------- CloudFront distribution — HTTPS termination for the EB frontend ----------
resource "aws_cloudfront_distribution" "frontend" {
  enabled             = true
  default_root_object = ""
  comment             = "${var.function_name} frontend"
  aliases             = ["discover.thefdeguy.com"]

  origin {
    domain_name = "${var.eb_cname_prefix}.${var.aws_region}.elasticbeanstalk.com"
    origin_id   = "eb-origin"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only" # EB only listens on HTTP
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    target_origin_id       = "eb-origin"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    forwarded_values {
      query_string = true
      cookies {
        forward = "none"
      }
    }

    # Short TTL — this is a dynamic app, not a static site
    min_ttl     = 0
    default_ttl = 0
    max_ttl     = 0
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.discover.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  tags = {
    Project = "ready-check"
  }

  depends_on = [aws_acm_certificate_validation.discover]
}

# ---------- S3 bucket to hold EB application versions ----------
resource "aws_s3_bucket" "eb_app_versions" {
  bucket = "${var.function_name}-eb-versions-${data.aws_caller_identity.current.account_id}"
}

data "aws_caller_identity" "current" {}

# ---------- IAM: EC2 instance profile (runs the app) ----------
resource "aws_iam_role" "eb_ec2_role" {
  name = "${var.function_name}-eb-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eb_web_tier" {
  role       = aws_iam_role.eb_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSElasticBeanstalkWebTier"
}

resource "aws_iam_instance_profile" "eb_ec2_profile" {
  name = "${var.function_name}-eb-ec2-profile"
  role = aws_iam_role.eb_ec2_role.name
}

# ---------- IAM: EB service role (manages the environment itself) ----------
resource "aws_iam_role" "eb_service_role" {
  name = "${var.function_name}-eb-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "elasticbeanstalk.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eb_service_health" {
  role       = aws_iam_role.eb_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSElasticBeanstalkEnhancedHealth"
}

resource "aws_iam_role_policy_attachment" "eb_service_managed" {
  role       = aws_iam_role.eb_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSElasticBeanstalkService"
}

# ---------- Render the frontend files with real Cognito/agent values baked in ----------
resource "local_file" "rendered_index" {
  content = templatefile("${path.module}/../frontend/public/index.html.tpl", {
    cognito_domain      = "https://${aws_cognito_user_pool_domain.domain.domain}.auth.${var.aws_region}.amazoncognito.com"
    cognito_client_id   = aws_cognito_user_pool_client.client.id
    elevenlabs_agent_id = var.elevenlabs_agent_id
  })
  filename = "${path.module}/build/frontend/public/index.html"
}

resource "local_file" "copied_server_js" {
  content  = file("${path.module}/../frontend/server.js")
  filename = "${path.module}/build/frontend/server.js"
}

resource "local_file" "copied_package_json" {
  content  = file("${path.module}/../frontend/package.json")
  filename = "${path.module}/build/frontend/package.json"
}

data "archive_file" "frontend_zip" {
  type        = "zip"
  source_dir  = "${path.module}/build/frontend"
  output_path = "${path.module}/build/frontend.zip"
  depends_on = [
    local_file.rendered_index,
    local_file.copied_server_js,
    local_file.copied_package_json,
  ]
}

resource "aws_s3_object" "frontend_package" {
  bucket = aws_s3_bucket.eb_app_versions.id
  key    = "frontend-${data.archive_file.frontend_zip.output_sha256}.zip"
  source = data.archive_file.frontend_zip.output_path
  etag   = data.archive_file.frontend_zip.output_md5
}

# ---------- Elastic Beanstalk application + environment ----------
resource "aws_elastic_beanstalk_application" "app" {
  name = "${var.function_name}-frontend"
}

resource "aws_elastic_beanstalk_application_version" "version" {
  name        = "v-${data.archive_file.frontend_zip.output_sha256}"
  application = aws_elastic_beanstalk_application.app.name
  bucket      = aws_s3_bucket.eb_app_versions.id
  key         = aws_s3_object.frontend_package.key
}

resource "aws_elastic_beanstalk_environment" "env" {
  name                = "${var.function_name}-env"
  application         = aws_elastic_beanstalk_application.app.name
  # UNVERIFIED against the currently available solution stacks in your
  # account/region — run:
  #   aws elasticbeanstalk list-available-solution-stacks --query "SolutionStacks[?contains(@,'Node.js')]"
  # and update this if it doesn't match exactly.
  solution_stack_name = var.eb_solution_stack_name
  version_label       = aws_elastic_beanstalk_application_version.version.name
  cname_prefix        = var.eb_cname_prefix

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "IamInstanceProfile"
    value     = aws_iam_instance_profile.eb_ec2_profile.name
  }

  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "ServiceRole"
    value     = aws_iam_role.eb_service_role.name
  }

  setting {
    namespace = "aws:autoscaling:asg"
    name      = "MinSize"
    value     = "1"
  }

  setting {
    namespace = "aws:autoscaling:asg"
    name      = "MaxSize"
    value     = "1"
  }
}
