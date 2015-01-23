from flask import Flask, request, Response
app = Flask(__name__)

@app.route('/ws')
def ws_test():
	page = '''\
<!DOCTYPE html>
<meta charset="utf-8" />
<title>WebSocket Test</title>
<script language="javascript" type="text/javascript">
  //var wsUri = "ws://echo.websocket.org/";
  var wsUri = "ws://lh:8800/___WS/abc";
  var output;
	function init() {
		output = document.getElementById("output");
		testWebSocket();
	}
	function testWebSocket() {
		websocket = new WebSocket(wsUri);
		websocket.onopen = function(evt) { onOpen(evt) };
		websocket.onclose = function(evt) { onClose(evt) };
		websocket.onmessage = function(evt) { onMessage(evt) };
		websocket.onerror = function(evt) { onError(evt) }; 
	}
	function onOpen(evt) {
		writeToScreen("CONNECTED");
		doSend("WebSocket rocks");
	}
	function onClose(evt) {
		writeToScreen("DISCONNECTED");
	}
	function onMessage(evt) {
		writeToScreen('<span style="color: blue;"> RESPONSE: ' + evt.data+'</span> ');
		//websocket.close(); 
	}
	function onError(evt) {
		writeToScreen('<span style="color: red;"> ERROR:</span> ' + evt.data);
	}
	function doSend(message) {
		writeToScreen("SENT: " + message);  websocket.send(message);
	}
	function writeToScreen(message) {
		var pre = document.createElement("p");
		pre.style.wordWrap = "break-word"; pre.innerHTML = message; output.appendChild(pre);
	}

    window.addEventListener("load", init, false);
</script>

<h2>WebSocket Test</h2>
<div id="output"></div>
'''
	return page


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




