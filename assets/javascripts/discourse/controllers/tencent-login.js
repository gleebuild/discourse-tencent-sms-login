// plugins/discourse-tencent-sms-login/assets/javascripts/discourse/controllers/tencent-login.js
import Controller from "@ember/controller";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { tracked } from "@glimmer/tracking";
import { inject as service } from "@ember/service";

export default class TencentLoginController extends Controller {
  @service siteSettings;
  
  @tracked phone = "";
  @tracked code = "";
  @tracked sent = false;
  @tracked sending = false;
  @tracked verifying = false;
  @tracked message = "";
  @tracked view = "login";
  @tracked resetPhone = "";
  @tracked resetCode = "";
  @tracked resetSent = false;
  @tracked resetSending = false;
  @tracked countdown = 0;
  @tracked timer = null;

  // 添加微信状态跟踪
  @tracked isWechatBrowser = /MicroMessenger/i.test(navigator.userAgent);
  
  constructor() {
    super(...arguments);
    // 安全初始化微信绑定
    if (this.isWechatBrowser) {
      this.bindWechatOpenId();
    }
  }

  // 微信OpenID绑定方法
  async bindWechatOpenId() {
    try {
      // 这里调用您的微信API获取openid
      const openid = await this.getWechatOpenId();
      if (openid) {
        await ajax("/tencent-sms/wechat-openid-callback", {
          type: "GET",
          data: { openid }
        });
      }
    } catch (error) {
      console.error("微信绑定失败", error);
    }
  }
  
  @action
  async sendCode() {
    this.sending = true;
    this.message = "";
    try {
      const r = await ajax("/tencent-sms/send", {
        type: "POST",
        data: { phone: this.phone }
      });
      this.sent = true;
      if (r.debug_code) {
        this.message = `DEBUG: 验证码 ${r.debug_code}`;
      } else {
        this.message = "验证码已发送";
      }
    } catch (e) {
      this.message = e.jqXHR?.responseJSON?.errors?.join(", ") || "发送失败";
    } finally {
      this.sending = false;
    }
  }
  
  // ... 其他方法保持不变 ...
}
