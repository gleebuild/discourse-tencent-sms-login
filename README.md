# Discourse Tencent SMS Login

This plugin extends the login experience by adding a **Phone SMS login** page using Tencent Cloud SMS.
It also includes password login, password reset, WordPress SSO relay and WeChat openid binding.

## Features

- SMS-based login and registration
- Password-based login
- Password reset via SMS verification
- WordPress SSO integration
- WeChat OpenID binding
- Support contact integration

## Install

1. SSH into your Discourse server
2. Edit `/var/discourse/containers/app.yml` and add this repo under `hooks: after_code:`:

```yaml
- git clone https://your.git/discourse-tencent-sms-login.git
