# How to run on FreeBSD 10.1

You'll need at least these packages, and their dependances.

	lua51-5.1.5_9                  Small, compilable scripting language providing easy access to C code
	nginx-devel-1.7.9              Robust and small WWW server
	redis-2.8.19                   Persistent key-value database with built-in net interface
	pcre-8.35_2                    Perl Compatible Regular Expressions library
	lua51-cjson-2.1.0              Fast JSON parsing and encoding support for Lua
	luajit-2.0.3                   Just-In-Time Compiler for Lua
	libffi-3.2.1                   Foreign Function Interface
	GeoIP-1.6.4                    Find the country that any IP address or hostname originates from

# NGINX + Lua

We require the latest Lua on Nginx code. It isn't (yet) in the FreeBSD nginx-dev package.
Similarly, the "openresty" code isn't available as a nice bundle either, although
all the individual modules are offered as options.

- go to /usr/ports/www/nginx-devel
- apply 2 patchs found in this directory: `Makefile.patch`, `distinfo.patch`
- enable this set of options (and more if you wish):
		ARRAYVAR
		ECHO
		ENCRYPTSESSION
		FILE_AIO
		HEADERS_MORE
		HTTP
		HTTP_ACCESSKEY
		HTTP_ADDITION
		HTTP_AUTH_DIGEST
		HTTP_AUTH_REQ
		HTTP_CACHE
		HTTP_EVAL
		HTTP_GEOIP
		HTTP_GUNZIP_FILTER
		HTTP_GZIP_STATIC
		HTTP_NOTICE
		HTTP_PUSH
		HTTP_PUSH_STREAM
		HTTP_REALIP
		HTTP_REDIS
		HTTP_RESPONSE
		HTTP_REWRITE
		HTTP_SECURE_LINK
		HTTP_SSL
		HTTP_SUBS_FILTER
		HTTP_UPLOAD
		HTTP_UPLOAD_PROGRESS
		HTTP_UPSTREAM_FAIR
		IPV6
		LET
		LUA
		RDS_JSON
		REDIS2
		SET_MISC
		SPDY
		WWW

- compile and install with: "make install"

- you should end up with something like this:
````shell
# nginx -V
nginx version: nginx/1.7.9
TLS SNI support enabled
configure arguments: --prefix=/usr/local/etc/nginx --with-cc-opt='-I
/usr/local/include' --with-ld-opt='-L /usr/local/lib'
--conf-path=/usr/local/etc/nginx/nginx.conf
--sbin-path=/usr/local/sbin/nginx --pid-path=/var/run/nginx.pid
--error-log-path=/var/log/nginx-error.log --user=www --group=www
--with-file-aio --with-ipv6
--http-client-body-temp-path=/var/tmp/nginx/client_body_temp
--http-fastcgi-temp-path=/var/tmp/nginx/fastcgi_temp
--http-proxy-temp-path=/var/tmp/nginx/proxy_temp
--http-scgi-temp-path=/var/tmp/nginx/scgi_temp
--http-uwsgi-temp-path=/var/tmp/nginx/uwsgi_temp
--http-log-path=/var/log/nginx-access.log
--add-module=/usr/ports/www/nginx-devel/work/nginx-accesskey-2.0.3
--with-http_addition_module
--add-module=/usr/ports/www/nginx-devel/work/samizdatco-nginx-http-auth-digest-bd1c86a
--with-http_auth_request_module
--add-module=/usr/ports/www/nginx-devel/work/openresty-echo-nginx-module-44c92a5
--add-module=/usr/ports/www/nginx-devel/work/openresty-headers-more-nginx-module-0c6e05d
--add-module=/usr/ports/www/nginx-devel/work/vkholodkov-nginx-eval-module-125fa2e
--with-http_geoip_module --with-http_gzip_static_module
--with-http_gunzip_module
--add-module=/usr/ports/www/nginx-devel/work/kr-nginx-notice-3c95966
--add-module=/usr/ports/www/nginx-devel/work/nginx_http_push_module-0.692
--add-module=/usr/ports/www/nginx-devel/work/wandenberg-nginx-push-stream-module-b6a8c46
--with-http_realip_module
--add-module=/usr/ports/www/nginx-devel/work/ngx_http_redis-0.3.7
--add-module=/usr/ports/www/nginx-devel/work/ngx_http_response-0.3
--add-module=/usr/ports/www/nginx-devel/work/yaoweibin-ngx_http_substitutions_filter_module-27a01b3
--with-http_secure_link_module
--add-module=/usr/ports/www/nginx-devel/work/nginx_upload_module-2.2.0
--add-module=/usr/ports/www/nginx-devel/work/masterzen-nginx-upload-progress-module-a788dea
--add-module=/usr/ports/www/nginx-devel/work/nginx_upstream_fair-20090923
--add-module=/usr/ports/www/nginx-devel/work/simpl-ngx_devel_kit-8dd0df5
--add-module=/usr/ports/www/nginx-devel/work/openresty-encrypted-session-nginx-module-49d741b
--add-module=/usr/ports/www/nginx-devel/work/arut-nginx-let-module-a5e1dc5
--add-module=/usr/ports/www/nginx-devel/work/openresty-lua-nginx-module-cea0699
--with-pcre
--add-module=/usr/ports/www/nginx-devel/work/openresty-rds-json-nginx-module-8292070
--add-module=/usr/ports/www/nginx-devel/work/openresty-redis2-nginx-module-78a7622
--add-module=/usr/ports/www/nginx-devel/work/openresty-set-misc-nginx-module-36fd035
--with-http_spdy_module --with-http_ssl_module
--add-module=/usr/ports/www/nginx-devel/work/openresty-array-var-nginx-module-4676747
````

## Other config

These are mostly personal preferences, but I also added:

	net.inet.ip.portrange.reservedhigh=0

To `/etc/sysctl.conf` so that any regular user can run nginx.

