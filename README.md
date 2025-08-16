# Discourse Tencent SMS Login (MVP)

This plugin replaces/extends the login experience by adding a **Phone SMS login** page using Tencent Cloud SMS.
It also exposes a minimal WordPress SSO relay and a WeChat openid binding endpoint.

## Install

1. SSH into your Discourse server (same way you install other plugins).
2. Edit `/var/discourse/containers/app.yml` and add this repo under `hooks: after_code:`:

```
- git clone https://your.git/discourse-tencent-sms-login.git
```

3. Rebuild:
```
cd /var/discourse
./launcher rebuild app
```

4. In Admin → Settings, search **Tencent SMS** and set:
   - `tencent_sms_enabled` = **true**
   - `tencent_sms_debug_mode` = true (for local testing; will not send SMS but logs/returns the code)
   - Fill SecretId/SecretKey/SdkAppId/Sign/Template when ready for production

5. Visit `/tencent-login` to test phone login. A button is also injected into the default login modal.

## Endpoints

- `POST /tencent-sms/send` `{ phone }` → send code
- `POST /tencent-sms/verify` `{ phone, code }` → verify only
- `POST /tencent-sms/login` `{ phone, code }` → verify & log user in (auto-create if needed)
- `POST /tencent-sms/wordpress-sso` → returns JSON with URL + payload + signature for your WP endpoint
- `GET /tencent-sms/wechat-openid-callback?openid=xxx` → saves to current_user custom_field

## Notes

- Codes are stored in `Discourse.cache` for 10 minutes.
- Phone is saved in `user.custom_fields["phone"]`.
- WeChat openid saved in `user.custom_fields["wechat_openid"]`.
- This is an MVP skeleton; you can replace `lib/tencent_sms_client.rb` with the official SDK call.
