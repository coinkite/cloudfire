
-- ngx.say("ERROR " .. ngx.status)
local tmp = ngx.re.sub(errors_html, '{{CODE}}', ''..ngx.status)

ngx.header['Content-Type'] = 'text/html; charset=utf-8'
set_no_cache()
ngx.say(tmp)
