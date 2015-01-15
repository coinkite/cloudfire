
-- see: https://github.com/openresty/lua-nginx-module#nginx-api-for-lua

local ck = require "cookie"
local cjson = require "cjson"
local hdrs = ngx.req.get_headers()
local cookie_name = 'FID'
local old_cookie = ngx.var.cookie_fid;

ngx.say("<pre>")
ngx.say("today = " .. ngx.time())
ngx.say("host = " .. hdrs.host)
ngx.say("path = " .. ngx.var.uri)

-- decode example here: http://www.stavros.io/posts/writing-an-nginx-authentication-module-in-lua/

local cookie, err = ck:new()
ngx.say("cookie = " .. cjson.encode(cookie))
ngx.say("err = " .. tostring(err))

if not cookie then
	ngx.log(ngx.ERR, err)
	return
end

local ok, err = cookie:set({key='heelo', value='123'})
ngx.say("ok = " .. tostring(ok))
ngx.say("err = " .. tostring(err))


-- ngx.say("val = " .. cjson.encode(hdrs))
-- ngx.say("path = " .. ngx.vars[1])

ngx.say("path = " .. ngx.var.uri)

-- ngx.say("set-cookie = " .. ngx.get_headers()['Set-Cookie'])
