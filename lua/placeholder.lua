-- ngx.say("ERROR " .. ngx.status)

local hdrs = ngx.req.get_headers()
local tmp = ngx.re.sub(placeholder_html, '{{HOSTNAME}}', hdrs.host or 'Website')

ngx.header['Content-Type'] = 'text/html; charset=utf-8'
set_no_cache()
ngx.say(tmp)
