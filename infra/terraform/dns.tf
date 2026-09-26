# ---------- ACM certificate (must be in us-east-1 for CloudFront) ----------
resource "aws_acm_certificate" "discover" {
  domain_name       = "discover.thefdeguy.com"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Project = "ready-check"
  }
}

# ---------- Route53: DNS validation records for the cert ----------
data "aws_route53_zone" "thefdeguy" {
  name         = "thefdeguy.com."
  private_zone = false
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.discover.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }

  zone_id = data.aws_route53_zone.thefdeguy.zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 60
  records = [each.value.record]
}

resource "aws_acm_certificate_validation" "discover" {
  certificate_arn         = aws_acm_certificate.discover.arn
  validation_record_fqdns = [for r in aws_route53_record.cert_validation : r.fqdn]
}

# ---------- Route53: A alias pointing discover.thefdeguy.com → CloudFront ----------
resource "aws_route53_record" "discover" {
  zone_id = data.aws_route53_zone.thefdeguy.zone_id
  name    = "discover.thefdeguy.com"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.frontend.domain_name
    zone_id                = aws_cloudfront_distribution.frontend.hosted_zone_id
    evaluate_target_health = false
  }
}
