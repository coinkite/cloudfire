import time
from flask import request, Response, render_template, json
from cfcapp import CFCFlask
	
app = CFCFlask(__name__)

@app.ws_rx_handler
def rx_data(vhost, conn, msg):
	say = msg['say']

	m = {'from': conn.fid[-8:].upper(), 'content': say}
	app.tx(m, bcast=True)

class Robot(object):
	def __init__(self):
		self.heard = set()

		@app.background_task
		def robot1():
			while 1:
				say = "I'm a robot and the time is %s" % time.strftime('%T')
				m = {'from': 'Robot1', 'content': say}
				app.tx(m, bcast=True)
				time.sleep(15)

		@app.ws_rx_handler
		def rx_data(vhost, conn, msg):
			said = msg['say']
			if 'robot' in said: return

			user = conn.fid[-8:].upper()
			if user not in self.heard:
				m = {'from': 'Robot1', 'content': "Hello %s" % user}
				app.tx(m, bcast=True)
				self.heard.add(user)

Robot()
	

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




