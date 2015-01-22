
-- see: https://github.com/openresty/lua-nginx-module#nginx-api-for-lua

local RDB = get_RDB()

-- must be before any content

local hdrs = ngx.req.get_headers()

local hostname = ngx.re.sub(hdrs.host or '', "^(.*)(:\\d*)|$", "$1")

-- map request to a redis key
local rkey = hostname .. '|' .. (ngx.var.uri or '/')

-- tracking
RDB:zincrby('activity', 1, rkey)

-- look it up (expecting a hash)
local values, err = RDB:hgetall(rkey)
if err or #values == 0 then
	LOG("Error/404 key = " .. rkey)
	ngx.exit(404)
end

-- stupid redis.lua code returns the redis list aka array as
-- a list of values. Need them to be name/value pairs
-- XXX use RDB:array_to_hash()
--   LOG(cjson.encode(values))

local status, content, content_hash = 200, 'EMPTY', nil
for idx = 1, #values, 2 do
	local name = values[idx]
	local val = values[idx+1]
	--LOG("n=" .. (name or 'nil') .. "  v=" .. (val or 'nil'))

	if name == '_content' then
		-- this key holds the HTML or image data itself (raw)
		content = val
	elseif _name == '_hash' then
		content_hash = val
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

if content_hash then
	-- do internal redirect, and serve as a static file.
	ngx.exec('/__S__/' .. content_hash)
else
	-- send it simplily
	ngx.print(content)
end
