import Controller from "@ember/controller";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { tracked } from "@glimmer/tracking";

export default class TencentLoginController extends Controller {
  @tracked phone = "";
  @tracked code = "";
  @tracked sent = false;
  @tracked message = "";

  @action async sendCode() {
    const r = await ajax("/tencent-sms/send", { type: "POST", data: { phone: this.phone } });
    this.sent = true;
    this.message = r.debug_code ? `DEBUG: ${r.debug_code}` : "已发送验证码";
  }

  @action async login() {
    const r = await ajax("/tencent-sms/login", { type: "POST", data: { phone: this.phone, code: this.code } });
    if (r.success) window.location = "/";
  }
}
