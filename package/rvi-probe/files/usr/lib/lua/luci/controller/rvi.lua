module("luci.controller.rvi", package.seeall)
function index()
  entry({"admin","network","rvi"}, call("redir"), _("RVInternetHelp Support"), 90)
end
function redir()
  luci.http.redirect("/cgi-bin/supportlink")
end
