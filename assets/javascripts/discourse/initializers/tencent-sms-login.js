// plugins/discourse-tencent-sms-login/assets/javascripts/discourse/initializers/tencent-sms-login.js
import { later } from "@ember/runloop";

export default {
  name: "tencent-sms-login",
  after: "inject-objects",
  
  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");
    if (!siteSettings.tencent_sms_enabled) return;
    
    // 确保Discourse完全初始化后再添加按钮
    later(() => {
      const loginButtons = document.querySelector(".login-buttons");
      if (loginButtons) {
        const smsButton = document.createElement("button");
        smsButton.className = "btn btn-primary tencent-sms-login-btn";
        smsButton.innerHTML = `
          <span class="d-icon d-icon-mobile-alt"></span>
          ${I18n.t("login.with_sms", { defaultValue: "短信登录" })}
        `;
        
        smsButton.addEventListener("click", () => {
          window.location.href = "/tencent-login";
        });
        
        loginButtons.appendChild(smsButton);
      }
    }, 500); // 延迟500ms确保安全
  },
};
