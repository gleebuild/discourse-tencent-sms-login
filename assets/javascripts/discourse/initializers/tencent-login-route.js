import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "tencent-login-route",
  initialize() {
    withPluginApi("1.14.0", (api) => {
      const addRoute =
        api.addFullPageRoute || // 旧版本
        api.addPageRoute ||     // 新版本
        api.addRoute;           // 最后兜底

      if (addRoute) {
        addRoute.call(api, "tencent-login", "tencent-login");
      } else {
        console.warn("[tencent-sms] Could not register route via plugin-api; navigate to /tencent-login directly.");
      }
    });
  },
};
