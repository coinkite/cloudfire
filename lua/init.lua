-- called by init_by_lua_file once, at server startup
--
cjson = require "cjson"

local tmp = io.open('lua/b-check.html', 'r'):read('*all')
browser_check_html = string.gsub(tmp, "<!--.--->", "")	-- special .- lua construct there

tmp = io.open('lua/b-check.js', 'r'):read('*all')
browser_check_js = string.gsub(tmp, '//.-\n', '')


ngx.log(ngx.INFO, 'LUA code init done')
