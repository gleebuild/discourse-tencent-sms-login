# frozen_string_literal: true
# name: discourse-tencent-sms-login
# about: Phone number login via Tencent Cloud SMS, plus WooCommerce SSO and WeChat openid binding
# version: 0.2.0
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
    post "/tencent-sms/send" => "tencent_sms#send_code"
    post "/tencent-sms/verify" => "tencent_sms#verify_code"
    post "/tencent-sms/login" => "tencent_sms#login"
    post "/tencent-sms/reset-password" => "tencent_sms#reset_password"
    post "/tencent-sms/wordpress-sso" => "tencent_sms#wordpress_sso"
    get  "/tencent-sms/wechat-openid-callback" => "tencent_sms#wechat_openid_callback"
    get "/tencent-login" => "tencent_sms#login_ui", constraints: { format: :html }
  end

  require_dependency "application_controller"

  class ::TencentSmsController < ::ApplicationController
    requires_plugin ::TencentSmsLogin::PLUGIN_NAME
    skip_before_action :verify_authenticity_token, only: [:send_code, :verify_code, :login, :reset_password, :wordpress_sso, :wechat_openid_callback]
    before_action :ensure_enabled

    def ensure_enabled
      raise Discourse::NotFound unless SiteSetting.tencent_sms_enabled
    end

    def send_code
      phone = normalize_phone(params.require(:phone))
      raise Discourse::InvalidParameters unless valid_phone?(phone)
      
      rate_key = "tencent_sms_rate_#{request.remote_ip}"
      rate = Discourse.redis.get(rate_key).to_i
      if rate > 10
        render_json_error I18n.t("tencent_sms.errors.too_many_requests"), status: 429
        return
      end
      Discourse.redis.incr(rate_key)
      Discourse.redis.expire(rate_key, 3600)

      code = "%06d" % rand(0..999999)
      Discourse.cache.write(sms_cache_key(phone), code, expires_in: 10.minutes)

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
      phone = normalize_phone(params.require(:phone))
      code = params.require(:code)
      cached = Discourse.cache.read(sms_cache_key(phone))
      if cached && ActiveSupport::SecurityUtils.secure_compare(cached, code)
        render_json_dump(valid: true)
      else
        render_json_dump(valid: false)
      end
    end

    def login
      phone = normalize_phone(params.require(:phone))
      code = params.require(:code)
      cached = Discourse.cache.read(sms_cache_key(phone))
      unless cached && ActiveSupport::SecurityUtils.secure_compare(cached, code)
        render_json_error I18n.t("tencent_sms.errors.code_invalid"), status: 400
        return
      end

      # 清除验证码缓存
      Discourse.cache.delete(sms_cache_key(phone))
      
      # 查找或创建用户
      user = find_or_create_user(phone)
      unless user
        render_json_error I18n.t("tencent_sms.errors.user_creation_failed"), status: 500
        return
      end

      # 登录用户
      log_on_user(user)
      render_json_dump(success: true, user_id: user.id, username: user.username)
    end
    
    def reset_password
      phone = normalize_phone(params.require(:phone))
      code = params.require(:code)
      new_password = params.require(:new_password)
      
      # 验证验证码
      cached = Discourse.cache.read(sms_cache_key(phone))
      unless cached && ActiveSupport::SecurityUtils.secure_compare(cached, code)
        render_json_error I18n.t("tencent_sms.errors.code_invalid"), status: 400
        return
      end
      
      # 查找用户
      user = UserCustomField.where(name: "phone").where(value: phone).first&.user
      unless user
        render_json_error I18n.t("tencent_sms.errors.user_not_found"), status: 404
        return
      end
      
      # 更新密码
      if user.update_password(new_password, user)
        # 清除验证码缓存
        Discourse.cache.delete(sms_cache_key(phone))
        render_json_dump(success: true)
      else
        render_json_error user.errors.full_messages.join(", "), status: 500
      end
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
      if current_user
        openid = params[:openid]
        if openid.present?
          current_user.custom_fields["wechat_openid"] = openid
          current_user.save_custom_fields(true)
        end
      end
      redirect_to "/"
    end
    
    private
    
    def normalize_phone(phone)
      phone.to_s.gsub(/\D/, '')[-11..-1]
    end
    
    def valid_phone?(phone)
      phone.present? && phone.length == 11
    end
    
    def sms_cache_key(phone)
      "tencent_sms_code:#{phone}"
    end
    
    def find_or_create_user(phone)
      # 通过手机号查找用户
      user = UserCustomField.where(name: "phone").where(value: phone).first&.user
      
      # 如果用户不存在则创建
      unless user
        username = generate_username(phone)
        email = "#{phone}@#{SiteSetting.tencent_sms_default_email_domain || 'example.com'}"
        
        user = User.new(
          username: username,
          email: email,
          name: "手机用户#{phone[-4..-1]}",
          active: true
        )
        
        begin
          user.password = SecureRandom.hex(16)
          if user.save
            user.custom_fields["phone"] = phone
            user.save_custom_fields(true)
          else
            Rails.logger.error "Tencent SMS User Creation Error: #{user.errors.full_messages.join(', ')}"
            return nil
          end
        rescue => e
          Rails.logger.error "Tencent SMS User Creation Error: #{e.message}"
          return nil
        end
      end
      
      user
    end
    
    def generate_username(phone)
      base_username = "mobile_#{phone[-6..-1]}"
      username = base_username
      suffix = 1
      
      while User.where(username: username).exists?
        suffix += 1
        username = "#{base_username}#{suffix}"
      end
      
      username
    end
  end

  # Tencent SMS client wrapper
  require_relative "lib/tencent_sms_client"
end
