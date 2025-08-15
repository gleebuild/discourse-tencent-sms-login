import Controller from "@ember/controller";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { tracked } from "@glimmer/tracking";
import { inject as service } from "@ember/service";

export default class TencentLoginController extends Controller {
  @service siteSettings;
  
  @tracked phone = "";
  @tracked code = "";
  @tracked password = "";
  @tracked newPassword = "";
  @tracked confirmPassword = "";
  @tracked sent = false;
  @tracked sending = false;
  @tracked verifying = false;
  @tracked message = "";
  @tracked view = "login"; // login, sms, password, reset-request, reset-verify, reset-password
  @tracked resetPhone = "";
  @tracked resetCode = "";
  @tracked resetSent = false;
  @tracked resetSending = false;
  @tracked countdown = 0;
  @tracked timer = null;

  constructor() {
    super(...arguments);
    // 检查是否在微信内打开
    if (this.isWechatBrowser()) {
      this.bindWechatOpenId();
    }
  }

  isWechatBrowser() {
    return navigator.userAgent.toLowerCase().indexOf('micromessenger') !== -1;
  }

  bindWechatOpenId() {
    // 这里需要实现微信OpenID获取逻辑
    // 实际项目中需要调用微信API获取openid
    const openid = this.getWechatOpenId();
    if (openid) {
      ajax("/tencent-sms/wechat-openid-callback", {
        type: "GET",
        data: { openid }
      });
    }
  }

  getWechatOpenId() {
    // 伪代码：实际项目中需要根据微信API获取openid
    return null;
  }

  @action
  showSmsLogin() {
    this.view = "sms";
    this.phone = "";
    this.code = "";
    this.sent = false;
  }

  @action
  showPasswordLogin() {
    this.view = "password";
    this.phone = "";
    this.password = "";
  }

  @action
  showResetRequest() {
    this.view = "reset-request";
    this.resetPhone = "";
    this.resetSent = false;
  }

  @action
  showResetVerify() {
    this.view = "reset-verify";
    this.resetCode = "";
  }

  @action
  showResetPassword() {
    this.view = "reset-password";
    this.newPassword = "";
    this.confirmPassword = "";
  }

  @action
  startCountdown(seconds = 60) {
    this.countdown = seconds;
    this.timer = setInterval(() => {
      this.countdown--;
      if (this.countdown <= 0) {
        clearInterval(this.timer);
        this.timer = null;
      }
    }, 1000);
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
      this.startCountdown();
      if (r.debug_code) {
        this.message = `DEBUG: code ${r.debug_code}`;
      } else {
        this.message = "验证码已发送";
      }
    } catch (e) {
      this.message = e.jqXHR?.responseJSON?.errors?.join(", ") || "发送失败";
    } finally {
      this.sending = false;
    }
  }

  @action
  async sendResetCode() {
    this.resetSending = true;
    this.message = "";
    try {
      const r = await ajax("/tencent-sms/send", {
        type: "POST",
        data: { phone: this.resetPhone }
      });
      this.resetSent = true;
      this.startCountdown();
      if (r.debug_code) {
        this.message = `DEBUG: code ${r.debug_code}`;
      } else {
        this.message = "验证码已发送";
        this.showResetVerify();
      }
    } catch (e) {
      this.message = e.jqXHR?.responseJSON?.errors?.join(", ") || "发送失败";
    } finally {
      this.resetSending = false;
    }
  }

  @action
  async login() {
    this.verifying = true;
    this.message = "";
    try {
      const r = await ajax("/tencent-sms/login", {
        type: "POST",
        data: { phone: this.phone, code: this.code }
      });
      if (r.success) {
        window.location = "/";
      }
    } catch (e) {
      this.message = e.jqXHR?.responseJSON?.errors?.join(", ") || "登录失败";
    } finally {
      this.verifying = false;
    }
  }

  @action
  async passwordLogin() {
    this.verifying = true;
    this.message = "";
    try {
      const r = await ajax("/session", {
        type: "POST",
        data: { login: this.phone, password: this.password }
      });
      if (r.success) {
        window.location = "/";
      }
    } catch (e) {
      this.message = e.jqXHR?.responseJSON?.errors?.join(", ") || "登录失败";
    } finally {
      this.verifying = false;
    }
  }

  @action
  async verifyResetCode() {
    this.verifying = true;
    this.message = "";
    try {
      const r = await ajax("/tencent-sms/verify", {
        type: "POST",
        data: { phone: this.resetPhone, code: this.resetCode }
      });
      if (r.valid) {
        this.showResetPassword();
      } else {
        this.message = "验证码错误或已过期";
      }
    } catch (e) {
      this.message = e.jqXHR?.responseJSON?.errors?.join(", ") || "验证失败";
    } finally {
      this.verifying = false;
    }
  }

  @action
  async resetPassword() {
    if (this.newPassword !== this.confirmPassword) {
      this.message = "两次输入的密码不一致";
      return;
    }
    
    this.verifying = true;
    this.message = "";
    try {
      const r = await ajax("/tencent-sms/reset-password", {
        type: "POST",
        data: { 
          phone: this.resetPhone, 
          code: this.resetCode,
          new_password: this.newPassword
        }
      });
      if (r.success) {
        this.message = "密码重置成功";
        setTimeout(() => {
          this.view = "login";
        }, 2000);
      }
    } catch (e) {
      this.message = e.jqXHR?.responseJSON?.errors?.join(", ") || "重置失败";
    } finally {
      this.verifying = false;
    }
  }

  @action
  contactSupport() {
    // 打开Discourse聊天窗口
    if (window.Discourse) {
      window.Discourse.__container__
        .lookup("service:chat")
        .startDmChannel([this.siteSettings.support_username]);
    }
  }
}
