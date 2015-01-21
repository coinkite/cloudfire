-- Verify their POW and create a session if ok
--

-- ngx.log(ngx.ERR, "BEFORE val = " .. cjson.encode(hdrs))
-- ngx.log(ngx.ERR, "BEFORE val = " .. url)

local hdrs = ngx.req.get_headers()

-- expecting an Ajax GET
if hdrs.x_requested_with ~= "XMLHttpRequest" then
	LOG("Not XMLHttpReq")
	ngx.exit(405)
end

args, err = ngx.req.get_uri_args(3)
if err then
	LOG("Bad args")
	ngx.exit(403)
end

local got_seed = args.seed
local got_pow = args.pow
local got_target = args.target

if not got_pow or not got_seed or not got_target then
	LOG("Missing pow/seed")
	ngx.exit(403)
end

LOG("Submission: pow=" .. args.pow .. "  seed=".. args.seed)

-- validate they did the RIGHT work.
local ip_addr = ngx.var.remote_addr
local their_seed, flags = seed_table:get(ip_addr)
if not their_seed then
	LOG("Unknown ip: " .. ip_addr)
	ngx.exit(403)
end
if their_seed ~= got_seed then
	LOG("Wrong seed: " .. got_seed)
	ngx.exit(403)
end

-- kill old seed so can only be tested once
seed_table:delete(ip_ddr)

if got_target ~= TARGET_VALUE then
	-- todo: handle changes to target on the fly
	LOG("Wrong target: " .. got_target)
	ngx.exit(403)
end

local ok = check_pow(got_seed, got_pow, got_target)
if not ok then
	LOG("POW work failed: " .. got_target)
	ngx.exit(403)
end

-- give them a working session, they are cool
local sid = pick_token()
local ok, err, overflowed = session_table:set(sid, ngx.var.remote_addr, SESSION_LIFETIME)
if not ok then
	LOG("Session create failed: " .. err)
	ngx.exit(400)
end
if overflowed then
	-- just for debug; consequence is someone (else) sees the browser-check an extra time
	LOG("Session table overflowed!")
end
	
-- grant the blessed cookie
-- NOTE: Do not set Domain or Path here, so applies to whole site.
local baked = 'FID='.. sid ..'; HttpOnly; Max-Age=' .. SESSION_LIFETIME
if ngx.var.https == 'on' then
	baked = baked .. '; Secure'
end
ngx.header['Set-Cookie'] = baked
set_no_cache()

-- rate limit delay, although consumes resources on our end
ngx.sleep(1)

-- return a simple string (can be empty)

-- MAYBE: we have a provision here to redirect to another page, like "site down", etc.
-- but better to do at a higher level or in more general way, so you can return a
-- URL instead of empty
-- ngx.say('/site-down')
ngx.say('')

-- impt: must return a 200 only if ok; else client may keep trying
