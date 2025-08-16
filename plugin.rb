# frozen_string_literal: true
# name: discourse-tencent-sms-login
# about: Phone number login via Tencent Cloud SMS, plus WooCommerce SSO and WeChat openid binding
# version: 0.1.1
# authors: GleeBuild + ChatGPT

enabled_site_setting :tencent_sms_enabled

after_initialize do
  module ::TencentSmsLogin
    PLUGIN_NAME = "discourse-tencent-sms-login"
  end

  Discourse::Application.routes.append do
    post "/tencent-sms/send" => "tencent_sms#send_code"
    post "/tencent-sms/verify" => "tencent_sms#verify_code"
    post "/tencent-sms/login" => "tencent_sms#login"
  end

  require_dependency "application_controller"

  class ::TencentSmsController < ::ApplicationController
    requires_plugin ::TencentSmsLogin::PLUGIN_NAME
    skip_before_action :verify_authenticity_token
    before_action :ensure_enabled

    def ensure_enabled
      raise Discourse::NotFound unless SiteSetting.tencent_sms_enabled
    end

    def send_code
      phone = params.require(:phone)
      code = "%06d" % rand(0..999999)
      Discourse.cache.write("tencent_sms_code:#{phone}", code, expires_in: 10.minutes)
      render_json_dump(success: true, debug_code: code) # MVP
    end

    def verify_code
      phone = params.require(:phone); code = params.require(:code)
      cached = Discourse.cache.read("tencent_sms_code:#{phone}")
      render_json_dump(valid: cached == code)
    end

    def login
      phone = params.require(:phone); code = params.require(:code)
      cached = Discourse.cache.read("tencent_sms_code:#{phone}")
      raise Discourse::InvalidParameters unless cached == code

      normalized = phone.gsub(/\s+/, "")
      user = UserCustomField.where(name: "phone", value: normalized).first&.user
      if user.blank?
        username = UserNameSuggester.suggest("u#{normalized.gsub(/\D/, '')}")
        user = User.create!(username: username, email: "phone+#{SecureRandom.hex(6)}@example.invalid", password: SecureRandom.hex(16), active: true)
        user.custom_fields["phone"] = normalized
        user.save_custom_fields(true)
      end
      log_on_user(user)
      render_json_dump(success: true)
    end
  end
end
