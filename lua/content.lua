
-- see: https://github.com/openresty/lua-nginx-module#nginx-api-for-lua

local RDB = get_RDB()

-- must be before any content
local hdrs = ngx.req.get_headers()

-- remove port number from hostname
local vhost = get_vhostname()

-- map request to a redis key
local rkey = vhost .. '|' .. (ngx.var.uri or '/')

-- look it up (expecting a hash)
local values, err = RDB:hgetall(rkey)
if err or #values == 0 then
	-- internal redirect to fastCGI. extend in nginx conf file.
	return ngx.exec('/__F__/' .. vhost)
end

-- tracking
-- RDB:hincrby(rkey, '_hits', 1)

-- redis.lua code returns the redis list aka array as
-- a list of values. Need them to be name/value pairs
values = RDB:array_to_hash(values)

local content, content_hash = 'EMPTY', nil
for name, val in pairs(values) do
	--LOG("n=" .. (name or 'nil') .. "  v=" .. (val or 'nil'))

	if name == '_content' then
		-- this key holds the HTML or image data itself (raw)
		content = val
		ngx.header['X-CFC-Hit'] = 'm'
	elseif name == '_hash' then
		content_hash = val
		ngx.header['X-CFC-Hit'] = 'd'
	elseif name == '_status' then
		-- control response status
		ngx.status = val
	elseif name == '_redirect' then
		-- we need ngx to handle complexity of relative urls and so on.
		return ngx.redirect('//' .. hdrs.host .. val, values._code or 302)
	elseif name == '_refresh' then
		-- use the value to update the key's timeout so stays in cache on read usage
		RDB:expire(val)
	elseif string.sub(name, 1,1) == '_' then
		-- ignore
	else 
		-- everything else is a header line
		ngx.header[name] = val
	end
end

if content_hash then
	-- do internal redirect, and serve as a static file.
	-- LOG(rkey .. ' => /__S__/' .. content_hash)
	return ngx.exec('/__S__/' .. content_hash)
else
	-- send it directly
	ngx.print(content)
end
