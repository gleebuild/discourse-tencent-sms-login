// plugins/discourse-tencent-sms-login/assets/javascripts/discourse/routes/tencent-login.js
import DiscourseRoute from "discourse/routes/discourse";

export default DiscourseRoute.extend({
  // 设置控制器名称
  controllerName: "tencent-login",
  
  // 添加模型钩子
  model() {
    return {};
  },
  
  // 页面加载时添加CSS类
  activate() {
    this.controllerFor("application").set("showTop", false);
    document.body.classList.add("tencent-login-page");
  },
  
  // 页面离开时移除CSS类
  deactivate() {
    document.body.classList.remove("tencent-login-page");
    this.controllerFor("application").set("showTop", true);
  },
  
  renderTemplate() {
    this.render("tencent-login");
  }
});
