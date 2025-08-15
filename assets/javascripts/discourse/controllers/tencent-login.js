import Controller from "@ember/controller";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { tracked } from "@glimmer/tracking";

export default class TencentLoginController extends Controller {
  @tracked phone = "";
  @tracked code = "";
  @tracked sent = false;
  @tracked sending = false;
  @tracked verifying = false;
  @tracked message = "";

  @action
  async sendCode() {
    this.sending = true;
    this.message = "";
    try {
      const r = await ajax("/tencent-sms/send", {
        type: "POST",
        data: { phone: this.phone },
      });
      this.sent = true;
      if (r.debug_code) {
        this.message = `DEBUG: code ${r.debug_code}`;
      } else {
        this.message = "Code sent";
      }
    } catch (e) {
      this.message = e.jqXHR?.responseJSON?.errors?.join(", ") || "Send failed";
    } finally {
      this.sending = false;
    }
  }

  @action
  async login() {
    this.verifying = true;
    this.message = "";
    try {
      const r = await ajax("/tencent-sms/login", {
        type: "POST",
        data: { phone: this.phone, code: this.code },
      });
      if (r.success) {
        window.location = "/";
      }
    } catch (e) {
      this.message = e.jqXHR?.responseJSON?.errors?.join(", ") || "Login failed";
    } finally {
      this.verifying = false;
    }
  }
}
