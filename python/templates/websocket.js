var wsUri = "ws://{{request.host}}/___WS";

var output;
function init() {
	output = document.getElementById("output");
	setupWebSocket();
}

function setupWebSocket() {
	websocket = new WebSocket(wsUri);
	websocket.onopen = function(evt) { onOpen(evt) };
	websocket.onclose = function(evt) { onClose(evt) };
	websocket.onmessage = function(evt) { onMessage(evt) };
	websocket.onerror = function(evt) { onError(evt) }; 
}
function onOpen(evt) {
	writeToScreen("--- CONNECTED ---");
}
function onClose(evt) {
	writeToScreen("--- DISCONNECTED ---");
}

function onMessage(evt) {

	var frame = JSON.parse(evt.data);
	console.log("rx=", frame);

	if(!frame.msg) return;

	var app = JSON.parse(frame.msg);
	console.log("app=", app);

	if(app) {
		writeToScreen('<span style="color: blue;">' + app.from + ':</span> ' + app.content);
	}
}
function onError(evt) {
	writeToScreen('<span style="color: red;">ERROR:</span> ' + evt.data);
}
function doSend(message) {
	message = JSON.stringify({'say': message});
	//writeToScreen("TX: " + message);
	websocket.send(message);
}
function writeToScreen(message) {
	var pre = document.createElement("pre");
	pre.style.wordWrap = "break-word";
	pre.innerHTML = message;
	output.appendChild(pre);
}

window.addEventListener("load", init, false);

