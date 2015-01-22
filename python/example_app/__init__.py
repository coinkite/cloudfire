from flask import Flask, request, Response
app = Flask(__name__)

@app.route('/')
@app.route('/<path:whatever>')
def hello_world(whatever=None):
	from pprint import pformat
	r = pformat(request.environ)
	r += "\n\n"
	r += pformat(request.environ['werkzeug.request'].__class__.__module__)
	r += "\n\n"
	r += "URL path: %s\n\n" % request.path
	r += "URL: %s" % request.url

	return Response(r, mimetype='text/plain')




