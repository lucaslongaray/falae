SecureHeaders::Configuration.default do |config|
  config.cookies = {
    secure: true,
    httponly: true,
    samesite: {
      lax: true
    }
  }

  # HSTS header is currently defined in the nginx configuration file. We'll keep
  # the same directive here in case the application moves out from nginx.
  # config.hsts = "max-age=#{1.year.to_i}; includeSubdomains; preload"
  config.hsts = SecureHeaders::OPT_OUT
  config.x_frame_options = "DENY"
  config.x_content_type_options = "nosniff"
  config.x_xss_protection = "1; mode=block"
  config.x_download_options = "noopen"
  config.x_permitted_cross_domain_policies = "none"
  config.referrer_policy = "strict-origin-when-cross-origin"

  # CSP allows inline scripts/style due application requirements
  config.csp = {
    preserve_schemes: true,
    base_uri: %w('self'),
    default_src: %w('self'),
    child_src: %w('none'),
    media_src: %w('none'),
    img_src: %w('self' data:),
    script_src: %w('self' 'unsafe-inline'),
    style_src: %w('self' 'unsafe-inline'),
    block_all_mixed_content: true,
  }

  config.csp_report_only = config.csp.merge({
    report_uri: %w(/csp-report)
  })
end
