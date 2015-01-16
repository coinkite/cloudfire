
-- see: https://github.com/openresty/lua-nginx-module#nginx-api-for-lua

local RDB = redis.new()
ok, err = RDB:connect('unix:redis.sock')
if not ok then
	LOG("RDB no connect: " .. err)
	ngx.exit(503)
end

-- must be before any content

local hdrs = ngx.req.get_headers()

-- map request to a redis key
local key = (hdrs.host or '') .. '|' .. (ngx.var.uri or '/')

-- tracking
RDB:zincrby('activity', 1, key)

-- look it up (expecting a hash)
local values, err = RDB:hgetall(key)
if err or #values == 0 then
	LOG("Error/404 key = " .. key)
	ngx.exit(404)
end

-- stupid redis.lua code returns the redis list aka array as
-- a list of values. Need them to be name/value pairs
--   LOG(cjson.encode(values))

local status, content = 200, 'EMPTY'
for idx = 1, #values, 2 do
	local name = values[idx]
	local val = values[idx+1]
	--LOG("n=" .. (name or 'nil') .. "  v=" .. (val or 'nil'))

	if name == '_' then
		-- this key holds the HTML or image data itself (raw)
		content = val
	elseif _name == '_status' then
		-- control response status
		ngx.resp.status = val
	elseif _name == '_refresh' then
		-- use the value to update the key's timeout so stays in cache on read usage
		RDB:expire(val)
	else 
		-- everything else is a header line
		ngx.req.set_header(name, val)
	end
end

-- send it.
ngx.print(content)
