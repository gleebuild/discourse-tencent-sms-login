# plugins/discourse-tencent-sms-login/plugin.rb
# frozen_string_literal: true
# name: discourse-tencent-sms-login
# about: 通过腾讯云短信实现手机登录
# version: 0.5.0
# authors: GleeBuild
# url: https://github.com/gleebuild/discourse-tencent-sms-login
# required_version: 3.0.0

enabled_site_setting :tencent_sms_enabled

after_initialize do
  module ::TencentSmsLogin
    PLUGIN_NAME = "discourse-tencent-sms-login"
  end

  # 添加安全协议检查和域名修复
  require_dependency "application_controller"
  
  class ::ApplicationController
    before_action :ensure_secure_protocol, if: :production?
    
    private
    
    def production?
      Rails.env.production?
    end
    
    def ensure_secure_protocol
      # 强制HTTPS协议
      if !request.ssl? && SiteSetting.force_https
        redirect_to protocol: "https://", status: :moved_permanently
        return
      end
      
      # 修复域名解析问题
      if request.host == "lebanx.com"
        # 使用实际配置的域名
        request.host = SiteSetting.force_hostname || ENV["DISCOURSE_HOSTNAME"] || "your-actual-domain.com"
      end
    end
  end

  # 简化路由避免冲突
  Discourse::Application.routes.append do
    # 使用标准入口
    get "/tencent-login" => "application#index"
    
    # 仅保留核心API路由
    post "/tencent-sms/send" => "tencent_sms#send_code"
    post "/tencent-sms/login" => "tencent_sms#login"
  end
  
  # 注册资源
  register_asset "stylesheets/common/tencent-login.scss"
  register_svg_icon "mobile-alt"
end
