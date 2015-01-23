-- web socket handler
-- see https://github.com/openresty/lua-resty-redis/issues/46 near end

local server = require "resty.websocket.server"
local RDB = get_RDB()

local wb, err = server:new({
	timeout = 1000,  				-- milliseconds
	max_payload_len = 4095,
})
if not wb then
	ngx.log(ngx.ERR, "failed to make new websocket: ", err)
	return ngx.exit(444)
end

function die(msg)
	-- connection is over.
	LOG("WS die: " .. msg)
	wb:send_close()
	return ngx.exit(ngx.OK)
end

--local myid = ngx.ctx.ACTIVE_FID .. '|' .. ngx.arg[1]
--LOG("ID = " .. myid)

local ok, err = RDB:subscribe("pusher")
if not ok then
	LOG("subscribe: " .. err)
	wb:send_close()
	return
end

wb:send_text("Connected!")

while true do 
	-- read and wait for next event on subscription channel
	local res, err = RDB:read_reply()
	if not res then
		return die('read sub: ' .. err)
	end

 	local mtype = res[1]
 	local chan = res[2]
 	local msg = res[3]
	LOG("Got msg: " .. mtype)

 	if mtype == "message" then
 		-- normal traffic on the channel
 		local ok, err = wb:send_text(msg)
 		if not ok then
 			die("Couldn't write: " .. err)
		end
	end
			
--x-- 	elseif mtype == "unsubscribe" then
--x-- 		break
--x-- 	end
end


wb:send_text("First msg")
wb:send_text("2nd msg")
while true do
 	wb:send_text("hello world")
 	ngx.sleep(5)
end

local data, typ, err = wb:recv_frame()

if not data then
	ngx.log(ngx.ERR, "failed to receive a frame: ", err)
	return ngx.exit(444)
end

