-- see: https://github.com/openresty/lua-nginx-module#nginx-api-for-lua

local RDB = redis.new()
ok, err = RDB:connect('unix:redis.sock')
if not ok then
	LOG("RDB no connect: " .. err)
	ngx.exit(503)
end

-- must be before any content
local hdrs = ngx.req.get_headers()
set_no_cache()

local args, err = ngx.req.get_uri_args(10)
if err then
	LOG("Bad args")
	kill_session()
	ngx.exit(403)
end

local curpw, _ = config_table:get('passwd')
ngx.log(ngx.INFO, 'PW = ' .. curpw)

if args.pw ~= curpw  then
	LOG("Wrong PW")
	kill_session()
	ngx.exit(403)
end

-- regex in config file pulls command out.
local cmd = ngx.var.admin_cmd;

if cmd == 'newpw' and args.newpw then
	-- NOTE: this only works if lua_code_cache is ON
	local s, e, f = config_table:set('passwd', args.newpw)
	LOG('System pw changed')
	ngx.say("New password applied")
elseif cmd == 'reload' then
	LOG('Reload server')
	--ngx.say(os.execute('kill -HUP ' .. ngx.var.pid))
	ngx.say(os.execute('env'))
	ngx.say(cjson.encode(ngx.ctx))
elseif cmd == 'execute' and args.cmd then
	LOG('Execute: ' .. args.cmd)
	ngx.say(os.execute('kill -HUP ' .. ngx.var.pid))
else
	LOG("Unknown/incorrrect cmd: " .. cmd)
	ngx.exit(404)
end

-- send it.
ngx.print("\n\nDone.")
