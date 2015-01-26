# CloudFIRE

### Open-Source Replacement for Cloudflare + Pubnub

![CloudFIRE Logo](img/cloudfire.svg "CloudFIRE")

After a recent outage, we wondered how hard it would be to replace
[Cloudflare](https://cloudflare) and their robot-protection code.
Once that worked, we realized that we had a decent front-end for websockets 
to operate at scale.

This codebase is a full stack for delivering web apps. It uses [NGINX](http://nginx.org/)
as the web server, and extends it with lots of custom Lua code. The Lua code
runs inside the memory of the Nginx workers, and provides the following services:

- fake browser detection and blocking.
- basic session cookies.
- websocket fan-out / message passing
- content cache from redis and/or disk
- generalized virtual hosting: a single IP can host many domains
- technologies applied: Nginx, Lua, Redis, OpenResty, Websockets, FastCGI, Python, Flask, FreeBSD.

It can serve static content, dynamic content via FastCGI
for each virtual host, and also serve static/cached content from Redis.

## Live Demo

Visit [cloudfire-demo.coinkite.com](http://cloudfire-demo.coinkite.com) for a quick
demo. It's quite basic: just a basic chat application with a simple robot.

## How It Works

### DDoS Protection

It's great to be able to "curl" your website, but when others are doing it
as a DDoS, it's less fun. The Lua code in this project checks all accesses
to the web server. If the new visitor does not have a session cookie
(managed by Lua, not your app), then a boring HTML page is rendered. That HTML
page contains Javascript to do a "proof of work" exercise and then posts the
result back to Lua. If the proof-of-work verifies, the user gets a cookie and
can proceed onto their usual content.

For real visitors, they have a Javascript-capable browser, so they are delayed
but not blocked and no captcha is needed.

For the PoW test, we're using SHA1 of a random seed (provided by the Lua code, so
it cannot be pre-computed) and a simple counter as a nonce. We want to see a
specific bit pattern anywhere in the hash hex. This is a simple check that both
the browser and server can do easily, but takes quite a few interations.  A typical
browser can complete the task in a few seconds. If someone were to develop custom
ASICs to solve these PoW problems, we'll increase the difficulty...  In fact, the
Lua code could do that automatically when it senses that new incoming traffic is
coming too fast.

### Dynamic Content vs. Caching

We use [Redis](http://redis.io/) to share state between FastCGI dynamic websites
and the Lua Code. All incoming URL's are checked against Redis to see if we should
provide a cached response. It's up the dynamic stuff to control what URL's are
in Redis for caching purposes. This system does only explicit caching at this point.

Boring redirects and smaller CSS/JS files can be put into Redis for
direct handling by the Lua code. For larger objects, contents are
served from disk based on the record found in Redis. This unlocks
the many features of Nginx, like *Etags* and *Range* requests, which
you want for larger objects.

Because this caching is explicit, you can upload an entire static website and
serve it directly from Nginx/Lua/Redis. See the python
helper program "[upload.py](python/upload.py)" to enable this.

There is no cache expiration, although if a key were to have limited
lifetime in Redis, you would get the same effect.

## Websockets

It's 2015, so we want to make modern websites that push data to the browser
as real-time events happen. We currently use [Pubnub](http://www.pubnub.com/)
at Coinkite, and they've never let us down. However, since we have Redis and Lua
in place, why not connect them? Then a CloudFIRE front-end can be the fan-out we
need for Websockets. Websockets, in my opinion, are ready to come of
age and be deployed more widely. CloudFIRE does not attempt any backwards compatibity
with older browsers w.r.t websockets. This looks safe based on our
research at [caniuse.com](http://caniuse.com/#search=websockets).

CloudFIRE accepts new websocket connections and implements them in Lua. (They are
rate-limited and managed via the same session cookies as normal HTTP traffic.)
Incoming traffic (from browser to server) is pushed onto a per-virtualhost
Redis *list*, which is easy to read
and decouples processing time from data rates (via [BLPOP](http://redis.io/commands/blpop)).
To send data from the server to
clients, the Lua code subscribes ([SUBSCRIBE](http://redis.io/commands/subscribe))
to a few specific channels, each of which can be written by the backend.

To do all this, the backend dynamic code must be connected to Redis and FastCGI.
The demo code does exactly this, using a few additions to the usual python/Flask setup.

We've provided Redis channels to send messages to every socket (broadcast),
only those of a single browser (session) or only to a specific web socket. When messages
are received from browsers, they are securely tracked as to their origin, so the
backend can be trust the origins of each message. (Be sure not to trust the contents
of the message though!)

## Backend Options

There is no requirement to use Python and Flask in the backend. Any
dynamic web server could be used as long as it can do FastCGI and
Redis. There is no need for complex async networking code, since
it will be only doing PUBLISH and BRPOP Redis commands for websockets.

In the FreeBSD directory, you'll find some deployment notes because
we used FreeBSD 10.1 to host this project.


#### Usage Notes

- Your backends should run as different users from the front end. They will communicate
  with CloudFIRE via Redis and FastCGI which is easily done via TCP on localhost.

- Each visitor will consume two sockets: one websocket and one connection to Redis.
  We haven't experimented yet with this "at scale" to see how well that works. 

- We require full duplex Lua socket support, so you'll need a recent version
  like [0.9.14 of the lua-nginx-module](https://github.com/openresty/lua-nginx-module/releases/tag/v0.9.14)

- You'll need to understand how to use NGINX effectively to be able to deploy this.

- Please use SSL for everything; we didn't for this demo to keep it simple.

- This code is just experimental at this point; we aren't using it in production.

- I think most CSRF issues would be solved by accepting form data via websocket only?!

- Lots more DDoS features could be added at the Lua layer. Like checking IP address
  black/white listing and rate limiting.

- Big props to the folks at [openresty.org](http://openresty.org/) who've done
  all the hard Lua stuff in this project.

## Future Directions

Some things we might do if we had more time...

- Lua placeholder HTMl templates should be uploadable or fetched from Redis.
  This would allow each vhost to customize the branding shown in their 404/502 pages.

- The present `upload.py` code is poor and needs a rewrite. It should probably post to
  an admin URL instead of using a mixture of Redis and admin URL's.

- The Flask code could be greatly improved with better integrate between CloudFIRE and
  the python code. For example, it could automatically upload all the static content
  based on standard flask configuration values.

- More statistics. The Lua code should collect stats and provide them via an admin URL
  or Redis.

- More fastness! Less memory!


## More about Coinkite

_Join The Most Powerful Bitcoin Platform_

Coinkite is the leading [bitcoin wallet](https://coinkite.com/faq/features) with
[multi-signature](https://coinkite.com/faq/multisig),
[bank-grade security](https://coinkite.com/faq/security),
[developer's API](https://coinkite.com/faq/developers) and [hardcore privacy](https://coinkite.com/privacy).

[Get Your Account Today!](https://coinkite.com/)



_At [Coinkite](https://coinkite.com), we have an internal program just like
Google's 20% time... We call it "weekends". Thanks for letting me finish this
on company time!_

