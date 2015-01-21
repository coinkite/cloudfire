-- called by init_by_lua_file once, at server startup
--
cjson = require "cjson"
redis = require "redis"

local tmp = io.open('lua/b-check.html', 'r'):read('*all')
browser_check_html = string.gsub(tmp, "<!--.--->", "")	-- special .- lua construct there

tmp = io.open('lua/b-check.js', 'r'):read('*all')
tmp = tmp .. io.open('lua/libs.js', 'r'):read('*all')
browser_check_js = string.gsub(tmp, '//.-\n', '')

local tmp = io.open('lua/errors.html', 'r'):read('*all')
errors_html = string.gsub(tmp, "<!--.--->", "")	-- special .- lua construct there

function LOG(msg)
	ngx.log(ngx.ERR, msg)
end

-- shared objects for LUA code
session_table = ngx.shared.sessions
seed_table = ngx.shared.seeds
config_table = ngx.shared.config

-- Must be a number in in lower-case hex. Might change at run-time to 
-- slow down visitors
TARGET_VALUE = '0beef'

SESSION_LIFETIME = 604800		-- one week in seconds

-- PW will change at runtime
local oldpw, _ = config_table:get('passwd')
if not oldpw then
	ngx.log(ngx.INFO, 'RESET system password')
	config_table:set('passwd', 'hello')
end

--
-- Some useful functions
--


function check_pow(seed, pow, target)
	-- validate our proof-of-work: SHA1 of seed should contain hex value "target"
	-- check pow is an integer
	if not pow:match('%d+') then
		return false
	end

	-- reconstruct the hashed value
	msg = seed .. '.' .. pow
	h = ndk.set_var.set_encode_hex(ngx.sha1_bin(msg))
	-- LOG('result ' .. h)

	return string.find(h, target)
end

function pick_token()
	-- random short string for use as seed or whatever
	return ndk.set_var.set_secure_random_alphanum(32)
end

function set_no_cache()
	-- add header lines to prevent caching
	ngx.header["Cache-Control"] = "no-cache, no-store, must-revalidate"
	ngx.header["Pragma"] = "no-cache"
	ngx.header["Expires"] = "0"
end

function kill_session()
	-- kill current session so they will have to re-prove themselves (also rate limits)
	fid = ngx.ctx.ACTIVE_FID
	if fid then
		session_table:delete(fid)
	end
end


ngx.log(ngx.INFO, 'LUA code init done')
