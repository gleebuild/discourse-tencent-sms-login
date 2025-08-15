// plugins/discourse-tencent-sms-login/assets/javascripts/discourse/initializers/tencent-login-route.js
import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "tencent-login-route",
  initialize() {
    withPluginApi("1.14.0", (api) => {
      // 使用兼容的API替代addFullPageRoute
      if (api.addRoute) {
        // 现代Discourse API
        api.addRoute("tencent-login", {
          path: "/tencent-login",
          templateName: "tencent-login",
          controllerName: "tencent-login",
          resetNamespace: true
        });
      } else if (api.addFullPageRoute) {
        // 旧版Discourse兼容
        api.addFullPageRoute("tencent-login", "tencent-login");
      } else {
        console.error("Tencent Login: 没有可用的路由API");
      }
    });
  },
};
