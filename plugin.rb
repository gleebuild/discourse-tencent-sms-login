# frozen_string_literal: true
# name: discourse-tencent-sms-login
# about: Phone number login via Tencent Cloud SMS, plus WooCommerce SSO and WeChat openid binding
# version: 0.1.0
# authors: GleeBuild + ChatGPT
# url: https://example.com/discourse-tencent-sms-login
# required_version: 3.0.0

enabled_site_setting :tencent_sms_enabled

after_initialize do
  module ::TencentSmsLogin
    PLUGIN_NAME = "discourse-tencent-sms-login"
  end

  # Routes for our controller
  Discourse::Application.routes.append do
    # ✅ 前端页面的服务器兜底：让 /tencent-login 走应用布局（交给 Ember 前端渲染）
    get "/tencent-login" => "tencent_sms#spa"

    post "/tencent-sms/send" => "tencent_sms#send_code"
    post "/tencent-sms/verify" => "tencent_sms#verify_code"
    post "/tencent-sms/login" => "tencent_sms#login"
    post "/tencent-sms/wordpress-sso" => "tencent_sms#wordpress_sso"
    get  "/tencent-sms/wechat-openid-callback" => "tencent_sms#wechat_openid_callback"
  end

  require_dependency "application_controller"

  class ::TencentSmsController < ::ApplicationController
    requires_plugin ::TencentSmsLogin::PLUGIN_NAME
    skip_before_action :verify_authenticity_token,
      only: [:send_code, :verify_code, :login, :wordpress_sso, :wechat_openid_callback]
    before_action :ensure_enabled, except: [:spa]

    def ensure_enabled
      raise Discourse::NotFound unless SiteSetting.tencent_sms_enabled
    end

    # ✅ 渲染空页面但使用 application 布局，让 Ember 前端接管 /tencent-login
    def spa
      render html: "", layout: true
    end

    def send_code
      phone = params.require(:phone)
      raise Discourse::InvalidParameters unless phone.present?
      rate_key = "tencent_sms_rate_#{request.remote_ip}"
      rate = Discourse.redis.get(rate_key).to_i
      if rate > 10
        render_json_error I18n.t("tencent_sms.errors.too_many_requests"), status: 429
        return
      end
      Discourse.redis.incr(rate_key)
      Discourse.redis.expire(rate_key, 3600)

      code = "%06d" % rand(0..999999)
      Discourse.cache.write("tencent_sms_code:#{phone}", code, expires_in: 10.minutes)

      if SiteSetting.tencent_sms_debug_mode
        Rails.logger.warn("[tencent-sms] DEBUG mode: code for #{phone} -> #{code}")
        render_json_dump(success: true, debug_code: code)
        return
      end

      client = ::TencentSmsClient.new(
        secret_id: SiteSetting.tencent_sms_secret_id,
        secret_key: SiteSetting.tencent_sms_secret_key,
        sdk_app_id: SiteSetting.tencent_sms_sdk_app_id,
        sign_name: SiteSetting.tencent_sms_sign_name,
        template_id: SiteSetting.tencent_sms_template_id
      )
      ok, err = client.send(phone, code)
      if ok
        render_json_dump(success: true)
      else
        render_json_error err || "send_failed", status: 500
      end
    end

    def verify_code
      phone = params.require(:phone)
      code = params.require(:code)
      cached = Discourse.cache.read("tencent_sms_code:#{phone}")
      if cached && ActiveSupport::SecurityUtils.secure_compare(cached, code)
        render_json_dump(valid: true)
      else
        render_json_dump(valid: false)
      end
    end

    def login
      phone = params.require(:phone)
      code = params.require(:code)
      cached = Discourse.cache.read("tencent_sms_code:#{phone}")
      unless cached && ActiveSupport::SecurityUtils.secure_compare(cached, code)
        render_json_error I18n.t("tencent_sms.errors.code_invalid"), status: 400
        return
      end

      # Find or create user by phone
      normalized = phone.gsub(/\s+/, "")
      user = UserCustomField.where(name: "phone").where(value: normalized).first&.user
      if user.blank?
        username = "u#{normalized.gsub(/\D/, "")}"
        username = UserNameSuggester.suggest(username)
        email = "phone+#{SecureRandom.hex(6)}@example.invalid"
        user = User.new(username: username, email: email)
        user.password = SecureRandom.hex(16)
        user.active = true
        if user.save
          user.custom_fields["phone"] = normalized
          user.save_custom_fields(true)
        else
          render_json_error user.errors.full_messages.join(", ")
          return
        end
      end

      log_on_user(user)
      render_json_dump(success: true, user_id: user.id, username: user.username)
    end

    # Minimal WordPress SSO relay: WordPress receives a signed payload and logs user in
    def wordpress_sso
      return render_json_error("disabled") unless SiteSetting.tencent_sms_wordpress_sso_url.present?
      raise Discourse::InvalidParameters unless current_user

      payload = {
        user_id: current_user.id,
        username: current_user.username,
        email: current_user.email,
        timestamp: Time.now.to_i
      }
      signature = OpenSSL::HMAC.hexdigest("SHA256", SiteSetting.tencent_sms_wordpress_sso_secret, payload.to_json)
      url = SiteSetting.tencent_sms_wordpress_sso_url

      render_json_dump(success: true, url: url, payload: payload, signature: signature)
    end

    def wechat_openid_callback
      # Placeholder for exchanging code->openid; store to user custom field
      if current_user
        openid = params[:openid]
        if openid.present?
          current_user.custom_fields["wechat_openid"] = openid
          current_user.save_custom_fields(true)
        end
      end
      redirect_to "/"
    end
  end

  # Tencent SMS client wrapper
  require_relative "lib/tencent_sms_client"
end
