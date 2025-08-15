# frozen_string_literal: true

class TencentSmsClient
  def initialize(secret_id:, secret_key:, sdk_app_id:, sign_name:, template_id:)
    @secret_id = secret_id
    @secret_key = secret_key
    @sdk_app_id = sdk_app_id
    @sign_name = sign_name
    @template_id = template_id
  end

  # Return [ok, error_message]
  def send(phone, code)
    # In production you should use the official Tencent Cloud SMS Ruby SDK.
    # Here we just log, because outbound network from Discourse container may be restricted.
    Rails.logger.info("[tencent-sms] send to #{phone} with code #{code}")
    [true, nil]
  rescue => e
    [false, e.message]
  end
end
