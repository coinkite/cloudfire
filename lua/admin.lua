-- see: https://github.com/openresty/lua-nginx-module#nginx-api-for-lua

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
elseif cmd == 'ping' then
	ngx.say("Pong")
elseif cmd == 'reload' then
	LOG('Reload server')
	os.execute('killall -v -HUP nginx')
elseif cmd == 'save' then
	-- save larger files onto disk "cache"
	LOG('Transfering files')
	local RDB = get_RDB()

	local additions, err = RDB:hgetall('new_files')
	if err then
		ngx.say("Problem.")
	else
		additions = RDB:array_to_hash(additions)
		for fname, data in pairs(additions)  do
			ngx.say(fname)
			local fd = io.open('static/' .. fname, 'w'):write(data)
			RDB:hdel('new_files', fname)
			RDB:sadd('all_files', fname)
		end
	end
elseif cmd == 'read' and args.host then
	local RDB = get_RDB()
	local hm = args.host
	local hits = RDB:keys(hm .. '|*')

	ngx.say(cjson.encode(hits))
		
elseif cmd == 'upload' then
	-- expecting a few args, and POST of a json document
	if ngx.req.method ~= 'POST' then
		ngx.exit(403)
	end
	ngx.req.read_body()
	keys = cjson.decode(ngx.req.get_body_data())
	local RDB = get_RDB()
	for key, val in pairs(keys) do
		RDB:hmset(key, val)
		ngx.say("set " .. key)
	end
		
elseif cmd == 'execute' and args.cmd then
	LOG('Execute: ' .. args.cmd)
	ngx.say(os.execute('kill -HUP ' .. ngx.var.pid))
else
	LOG("Unknown/incorrrect cmd: " .. cmd)
	ngx.exit(404)
end

-- send it.
ngx.print("\n\nDone.")
