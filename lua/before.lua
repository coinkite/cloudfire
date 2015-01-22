--
-- Force them to have a cookie already.
--
-- Dox here: https://github.com/openresty/lua-nginx-module#nginx-api-for-lua
--

local url = ngx.var.uri

-- local hdrs = ngx.req.get_headers()
-- ngx.log(ngx.ERR, "BEFORE val = " .. cjson.encode(hdrs))
-- ngx.log(ngx.ERR, "BEFORE val = " .. url)

function get_url_prefix()
	local from, to = ngx.re.find(url, "/[a-z0-9_]*")
	if from then
		return string.sub(url, from, to)
	end

	return '/'
end

function send_away()
	-- missing cookie(s)
	-- can't work

	-- Must set headers before first part of body

	-- send some html, customized for this visitor
	--ngx.req.set_header('Content-Type', 'text/html; charset=utf-8')
	ngx.header['Content-Type'] = 'text/html; charset=utf-8'
	-- clear any junk cookies, old sessions, etc
	ngx.header['Set-Cookie'] = { 'FID=DELETED; HttpOnly; Secure; Path=/; Max-Age=-100', 
									'FID=DELETED; HttpOnly; Path=/; Max-Age=-100'}
	set_no_cache()

	local prefix = get_url_prefix()
	if prefix == '/__S__' then
		-- if it's a static object, fail now because giving them html won't work
		ngx.exit(403)
	end
	if ngx.req.method == 'POST' then
		ngx.exit(403)
	end


	-- Send body
	ngx.say(browser_check_html)
	local ip_addr = ngx.var.remote_addr
	local old_seed, unused = seed_table:get(ip_addr)
	if old_seed then
		-- force them to keep same seed if coming from same IP; limits the damage of
		-- flood from single IP addr
		seed = old_seed
	else
		-- new random seed
		seed = pick_token()

		-- add to see table, but with limited lifetime
		ok, err = seed_table:safe_set(ngx.var.remote_addr, seed, 30)
		if not ok then
			-- this is ok, just means we're being flooded a bit
			-- we will recover as seeds expire from the table
			LOG("Out of space in seed table: " .. err)
			ngx.exit(429)
		end
	end

	ngx.say('SEED="' .. seed .. '";')
	ngx.say('TARGET="' .. TARGET_VALUE .. '";')
	ngx.say(browser_check_js)
	ngx.say('</script></body></html')


	ngx.exit(200)
end

local got_fid = ngx.var.cookie_fid

if not got_fid or got_fid:len() > 80 or got_fid:len() < 16 then
	-- had no (FI) session cookie
	send_away()
end

local ok, unused_flags = session_table:get(got_fid)
if not ok then
	-- has unknown / stale / fake session token
	LOG("Unknown session: " .. got_fid)
	send_away()
end

-- record provided session token for later need
ngx.ctx.ACTIVE_FID = got_fid

-- check if valid session. They are time limited.

