-- web socket handler
-- see https://github.com/openresty/lua-resty-redis/issues/46 near end

local MAX_WS_PER_FID = 3
local server = require "resty.websocket.server"

-- validate channel string, because it's unclean
local subchan = ngx.var.query_string or 'none'
local cleaned, n, err = ngx.re.sub(subchan, '^([a-z0-9A-Z.]{1,100})$', '$1')
if cleaned ~= subchan or n ~= 1 or err then
	LOG("got chan: " .. subchan .. " => " .. cleaned)
	return ngx.exit(404)
end

-- first of two connections to db
local RDB = get_RDB()

-- check valid channel
local valid_channels, _ = config_table:get('channels')
if valid_channels then
	if not valid_channels[subchan] then
		LOG("unknown chan: " .. subchan)
		return ngx.exit(404)
	end
else
	-- this is a configuration error
	LOG("Accepting any channel name!")
end

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
local STATE = { wsid = wsid, fid = fid, chan=subchan, sock=wb, die=die }

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
		STATE:report(RDB, nil, True)
	end

	return ngx.exit(ngx.OK)
end

-- check this user isn't using too many browser windows, and provide linkage mapping
local count = RDB:rpush('sockets|fid|' .. fid, wsid)
if count and count > MAX_WS_PER_FID then
	return STATE:die("too many")
end

-- tell both client and server what their id's are.
local public_state = { wsid = wsid, fid = ngx.ctx.ACTIVE_FID, chan=subchan }
RDB:sadd('sockets', wsid)
RDB:hmset('sockets|wsid|' .. wsid, public_state)
wb:send_text(cjson.encode(public_state))

-- internal "methods". don't want to record these into redis tho
STATE.report = function(STATE, XRDB, raw, is_closed)
	m = { wsid=STATE.wsid, fid=STATE.fid }
	if is_closed then
		m.state = 'CLOSED'
	else
		m.msg = raw
	end

	XRDB:rpush('websocket_rx|' .. STATE.chan, cjson.encode(m))
end

-- see https://github.com/openresty/lua-resty-websocket/issues/1#issuecomment-24816008
local function client_rx(STATE)
	local RDB = get_RDB()
	local wb = STATE.sock
	LOG("client_rx starts")

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


-- SUBSCRIBE -- cannot do normal redis after this.
local ok, err = RDB:subscribe("bcast", 
								"fid|"..fid,
								"chan|"..subchan,
								"wsid|"..wsid
							)
if not ok then
	LOG("subscribe: " .. err)
	wb:send_close()
	return
end

while true do 
	-- read and wait for next event on subscription channel
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
				local ok, err = wb:send_text(cjson.encode({chan=chan, msg=msg}))
				if not ok then
					STATE:die("Couldn't write: " .. err)
				end
			end
					
		elseif mtype == "unsubscribe" then
			break
		end
	end
end


