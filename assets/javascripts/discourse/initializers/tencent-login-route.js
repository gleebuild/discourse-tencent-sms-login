import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "tencent-login-route",
  initialize() {
    withPluginApi("1.14.0", (api) => {
      const addRoute = api.addFullPageRoute || api.addPageRoute || api.addRoute;
      if (addRoute) {
        addRoute.call(api, "tencent-login", "tencent-login");
      } else {
        console.warn("[tencent-sms] Could not register route via plugin-api; navigate to /tencent-login directly.");
      }
    });
  },
};
