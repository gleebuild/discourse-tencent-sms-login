import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "tencent-login-route",
  initialize() {
    withPluginApi("1.14.0", (api) => {
      api.addFullPageRoute("tencent-login", "tencent-login");
    });
  },
};
