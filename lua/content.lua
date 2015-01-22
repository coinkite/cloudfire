
-- see: https://github.com/openresty/lua-nginx-module#nginx-api-for-lua

local RDB = get_RDB()

-- must be before any content

local hdrs = ngx.req.get_headers()

-- remove port number from hostname
local hostname = ngx.re.sub(hdrs.host or '', "^(.*?)((:\\d*)|)$", "$1")

-- map request to a redis key
local rkey = hostname .. '|' .. (ngx.var.uri or '/')

-- tracking
RDB:zincrby('activity', 1, rkey)
--ngx.header['X-CFC-Key'] = rkey

-- look it up (expecting a hash)
local values, err = RDB:hgetall(rkey)
if err or #values == 0 then
	LOG("Error/404 rkey = " .. rkey)
	ngx.exit(404)
end

-- redis.lua code returns the redis list aka array as
-- a list of values. Need them to be name/value pairs
values = RDB:array_to_hash(values)

local content, content_hash = 'EMPTY', nil
for name, val in pairs(values) do
	--LOG("n=" .. (name or 'nil') .. "  v=" .. (val or 'nil'))

	if name == '_content' then
		-- this key holds the HTML or image data itself (raw)
		content = val
	elseif name == '_hash' then
		content_hash = val
	elseif name == '_status' then
		-- control response status
		ngx.resp.status = val
	elseif name == '_refresh' then
		-- use the value to update the key's timeout so stays in cache on read usage
		RDB:expire(val)
	else 
		-- everything else is a header line
		ngx.header[name] = val
	end
end

if content_hash then
	-- do internal redirect, and serve as a static file.
	LOG(rkey .. ' => /__S__/' .. content_hash)
	ngx.exec('/__S__/' .. content_hash)
else
	-- send it simplily
	LOG(' quick path' )
	ngx.print(content)
end
