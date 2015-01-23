-- web socket handler
-- see https://github.com/openresty/lua-resty-redis/issues/46 near end

-- validate channel string, because it's unclean
local subchan = ngx.var.query_string or 'none'
local cleaned, n, err = ngx.re.sub(subchan, '^([a-z0-9A-Z]{1,100})$', '$1')
if cleaned ~= subchan or n ~= 1 or err then
	LOG("got chan: " .. subchan .. " => " .. cleaned)
	return ngx.exit(404)
end

local MAX_WS_PER_FID = 3
local server = require "resty.websocket.server"
local RDB = get_RDB()

local wb, err = server:new({
	timeout = 0,  				-- milliseconds
	max_payload_len = 4095,
})
if not wb then
	ngx.log(ngx.ERR, "failed to make new websocket: ", err)
	return ngx.exit(444)
end

local fid = 'fid|' .. ngx.ctx.ACTIVE_FID

-- make a fully unique id, as handle for this specific connection
local wsid = pick_token()

local function die(msg, fid, wsid)
	-- connection is over.
	LOG(wsid .. ": dies: " .. msg)
	wb:send_close()

	-- must unsubscribe first! Can't do redis otherwise.
	RDB:unsubscribe()

	-- clean up records; might not be rock solid, but okay
	RDB:lrem('sockets|' .. fid, 0, wsid)
	RDB:del('sockets|wsid|', wsid)
	RDB:srem('sockets', wsid)

	return ngx.exit(ngx.OK)
end

-- check this user isn't using too many windows, and provide mapping
local count = RDB:rpush('sockets|' .. fid, wsid)
if count and count > MAX_WS_PER_FID then
	return die("too many", fid, wsid)
end

-- document our status
local status = { wsid = wsid, fid = ngx.ctx.ACTIVE_FID, chan=subchan }
RDB:sadd('sockets', wsid)
RDB:hmset('sockets|wsid|' .. wsid, status)

wb:send_text(cjson.encode(status))

-- see https://github.com/openresty/lua-resty-websocket/issues/1#issuecomment-24816008
local function client_rx(wb, fid, wsid)
	local RDB = get_RDB()

	wb:set_timeout(0)
	while true do
		local bytes, typ, err = wb:recv_frame()
		if wb.fatal then
			-- comes here if they reload the page, close laptop, whatever.
			return die("rx fatal", fid, wsid)
		elseif err then
			-- for timeouts.
			LOG("err=" .. err)
			return die("rx error", fid, wsid)
		elseif typ == "close" then
			return die("client close", fid, wsid)
		elseif typ == "text" then
			-- LOG(wsid .. ": RX: " ..  bytes)
			RDB:rpush("websocket_rx", cjson.encode({wsid=wsid, msg=bytes}))
		end
	end
end

-- start another thread is listen for traffic from caller
ngx.thread.spawn(client_rx, wb, fid, wsid)


-- SUBSCRIBE -- cannot do normal redis after this.
local ok, err = RDB:subscribe("bcast", fid,
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
			return die('read sub: ' .. err, fid, wsid)
		end
	else

		local mtype = res[1]
		local chan = res[2]
		local msg = res[3]

		if mtype == "message" then
			-- normal traffic on the channel; copy to websocket
			if msg == 'PING' then
				wb:send_ping('hi')
			else
				local ok, err = wb:send_text(cjson.encode({chan=chan, msg=msg}))
				if not ok then
					die("Couldn't write: " .. err, fid, wsid)
				end
			end
					
		elseif mtype == "unsubscribe" then
			break
		end
	end
end


