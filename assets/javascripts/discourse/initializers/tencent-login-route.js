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
        // name, template
        addRoute.call(api, "tencent-login", "tencent-login");
      } else {
        // 即使没有 helper，也能通过服务器兜底路由 /tencent-login 打开页面
        // 这里只做降级日志，不抛错，避免首页 spinner 卡死
        // eslint-disable-next-line no-console
        console.warn("[tencent-sms] Could not register route via plugin-api; navigate to /tencent-login directly.");
      }
    });
  },
};
