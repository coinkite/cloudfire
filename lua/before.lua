--
-- Force them to have a cookie already.
--
-- Dox here: https://github.com/openresty/lua-nginx-module#nginx-api-for-lua
--

local old_cookie = ngx.var.cookie_fid
local hdrs = ngx.req.get_headers()
local cjson = require "cjson"
local url = ngx.var.uri

-- ngx.log(ngx.ERR, "BEFORE val = " .. cjson.encode(hdrs))
ngx.log(ngx.ERR, "BEFORE val = " .. url)

local got_a = ngx.cookie_fi_a
local got_b = ngx.cookie_fi_b
local got_c = ngx.cookie_fi_c

local from, to = ngx.re.find(url, "/[a-z0-9_]*")
if from then
	prefix = string.sub(url, from, to)
else
	prefix = '/'
end
ngx.log(ngx.ERR, "Prefix: " .. prefix)

if not got_a or not got_b or not got_c then
	-- missing cookie(s)
	-- can't work

	if prefix == '/static' then
		-- if it's a static object, fail now with 401 because giving them html won't work
		ngx.exit(403)
	end
	if ngx.req.method == 'POST' then
		ngx.exit(403)
	end

	-- send some html, customized for this visitor
	ngx.req.set_header('Content-Type', 'text/html')
	ngx.say(browser_check_html)
	ngx.say('AAA="sdfsdf"')
	ngx.say(browser_check_js)
	ngx.say('</script></body></html')
	ngx.exit(200)
end
