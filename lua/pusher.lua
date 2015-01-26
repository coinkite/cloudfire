--
-- Web socket handler in lua+redis.
--
-- see https://github.com/openresty/lua-resty-redis/issues/46 near end

local MAX_WS_PER_FID = 3
local server = require "resty.websocket.server"

-- no channels, but instead each virtual host has a grouping
local vhost = get_vhostname()

-- first of two connections to db
local RDB = get_RDB()

local wb, err = server:new({
	timeout = 0,  				-- milliseconds
	max_payload_len = 4095,
})
if not wb then
	ngx.log(ngx.ERR, "failed to make new websocket: ", err)
	return ngx.exit(500)
end

-- document our status .. look almost an "object"; we're so OOP
local fid = ngx.ctx.ACTIVE_FID
local wsid = pick_token() -- fully unique id, as handle for this specific connection
local STATE = { wsid = wsid, fid = fid, vhost=vhost, sock=wb, die=die }

STATE.die = function(STATE, msg)
	-- connection is over.
	LOG(STATE.wsid .. ": dies: " .. msg)
	STATE.sock:send_close()

	-- must unsubscribe first! Can't do redis otherwise.
	RDB:unsubscribe()

	-- clean up records; might not be rock solid, but okay
	RDB:lrem('sockets|fid|' .. STATE.fid, 0, STATE.wsid)
	RDB:del('sockets|wsid|', STATE.wsid)
	RDB:srem('sockets', STATE.wsid)
	if STATE.report then
		STATE:report(RDB, nil, "CLOSE")
	end

	return ngx.exit(ngx.OK)
end

-- check this user isn't using too many browser windows, and provide linkage mapping
local count = RDB:rpush('sockets|fid|' .. fid, wsid)
if count and count > MAX_WS_PER_FID then
	return STATE:die("too many")
end

-- tell both client and server what their id's are.
local public_state = { wsid = wsid, fid = ngx.ctx.ACTIVE_FID, vhost=vhost }
RDB:sadd('sockets', wsid)
RDB:hmset('sockets|wsid|' .. wsid, public_state)
wb:send_text(cjson.encode(public_state))

-- method to send traffic to server
STATE.report = function(STATE, XRDB, raw, state_changed)
	m = { wsid=STATE.wsid, fid=STATE.fid }
	if state_changed then
		m.state = state_changed
	else
		m.msg = raw
	end

	XRDB:rpush('rx|' .. STATE.vhost, cjson.encode(m))
end

-- see https://github.com/openresty/lua-resty-websocket/issues/1#issuecomment-24816008
local function client_rx(STATE)
	local RDB = get_RDB()
	local wb = STATE.sock

	wb:set_timeout(0)
	while true do
		local bytes, typ, err = wb:recv_frame()
		if wb.fatal then
			-- comes here if they reload the page, close laptop, whatever.
			return STATE:die("rx fatal")
		elseif err then
			-- for timeouts.
			LOG("err=" .. err)
			return STATE:die("rx error")
		elseif typ == "close" then
			return STATE:die("client close")
		elseif typ == "text" then
			-- LOG(wsid .. ": RX: " ..  bytes)
			STATE:report(RDB, bytes)
		end
	end
end

-- start another thread is listen for traffic from caller
ngx.thread.spawn(client_rx, STATE)

STATE:report(RDB, nil, "OPEN")

-- SUBSCRIBE -- cannot do normal redis after this.
local ok, err = RDB:subscribe("bcast", 
								"fid|"..fid,
								"vhost|"..vhost,
								"wsid|"..wsid
							)
if not ok then
	LOG("subscribe: " .. err)
	wb:send_close()
	return
end

while true do 
	-- read and wait for next event on subscription channels
	local res, err = RDB:read_reply()
	if not res then
		if err == 'timeout' then
			wb:send_ping('')
		else
			return STATE:die('read sub: ' .. (err or 'nil'))
		end
	else
		-- finish the redis response parsing
		local mtype = res[1]
		local chan = res[2]
		local msg = res[3]

		if mtype == "message" then
			-- looking for a few specialized messages from server
			if msg == 'PING' then
				wb:send_ping('')
			elseif msg == 'CLOSE' then
				wb:send_close()
			else
				-- normal traffic on the channel; copy to websocket
				local ok, err = wb:send_text(msg)
				if not ok then
					STATE:die("Couldn't write: " .. err)
				end
			end
					
		elseif mtype == "unsubscribe" then
			break
		end
	end
end


