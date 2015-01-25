from flask import request, Response, render_template, json
from cfcapp import CFCFlask
	
app = CFCFlask(__name__)

@app.ws_rx_handler
def rx_data(vhost, conn, msg):
	say = json.loads(msg)['say']
	m = json.dumps({'from': conn.fid[-8:].upper(),
					'content': say})
	app.tx(m, bcast=True)

@app.route('/')
def ws_test():
	return render_template("chat.html", vhost=request.host)


@app.route('/debug')
@app.route('/debug/<path:whatever>')
def hello_world(whatever=None):
	from pprint import pformat
	r = pformat(request.environ)
	r += "\n\n"
	r += pformat(request.environ['werkzeug.request'].__class__.__module__)
	r += "\n\n"
	r += "URL path: %s\n\n" % request.path
	r += "URL: %s" % request.url

	return Response(r, mimetype='text/plain')




