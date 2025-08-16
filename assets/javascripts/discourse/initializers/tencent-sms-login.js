import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "tencent-sms-login",
  initialize() {
    withPluginApi("1.14.0", (api) => {
      api.modifyClass("component:login-buttons", {
        pluginId: "tencent-sms-login",
        didInsertElement() {
          this._super(...arguments);
          const el = document.createElement("a");
          el.className = "btn btn-primary tencent-sms-login-btn";
          el.innerText = "手机号短信登录";
          el.href = "/tencent-login";
          this.element.appendChild(el);
        },
      });
    });
  },
};
