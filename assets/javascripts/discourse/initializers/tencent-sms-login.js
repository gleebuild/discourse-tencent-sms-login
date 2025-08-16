import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "tencent-sms-login",
  initialize() {
    withPluginApi("1.14.0", (api) => {
      // Add a button to the login modal to open our route
      api.modifyClass("component:login-buttons", {
        pluginId: "tencent-sms-login",
        didInsertElement() {
          this._super(...arguments);
          const el = document.createElement("button");
          el.className = "btn btn-primary tencent-sms-login-btn";
          el.innerText = I18n.t("login.with_sms", { defaultValue: "Use phone SMS login" });
          el.addEventListener("click", () => {
            window.location.href = "/tencent-login";
          });
          this.element.appendChild(el);
        },
      });
    });
  },
};
