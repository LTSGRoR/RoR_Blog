# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy.
# See the Securing Rails Applications Guide for more information:
# https://guides.rubyonrails.org/security.html#content-security-policy-header

Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.font_src    :self, :https, :data
    policy.img_src     :self, :https, :data, :blob
    policy.object_src  :none
    # Allow importmap scripts (self) and inline scripts needed by Turbo/Stimulus via nonce
    policy.script_src  :self, :https, "https://unpkg.com", "https://cdn.jsdelivr.net"
    # Allow Tailwind inline styles and external CDN stylesheets
    policy.style_src   :self, :https, :unsafe_inline, "https://unpkg.com", "https://cdn.jsdelivr.net"
    policy.connect_src :self
    policy.frame_src   :none
    policy.base_uri    :self
    policy.form_action :self
  end

  # Generate session nonces for permitted importmap and inline scripts.
  config.content_security_policy_nonce_generator = ->(request) { request.session.id.to_s }
  config.content_security_policy_nonce_directives = %w[script-src]
end
