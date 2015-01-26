var wsUri = "{{CFC.WEBSOCKET_URL}}";

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

	var msg = JSON.parse(evt.data);
	console.log("msg=", msg);

	if(msg.from) {
		writeToScreen('<span style="color: blue;">' + msg.from + ':</span> ' + msg.content);
	}
}
function onError(evt) {
	writeToScreen('<span style="color: red;">ERROR:</span> ' + evt.data);
}
function doSend(message) {
	message = JSON.stringify({'say': message});
	websocket.send(message);
}
function writeToScreen(message) {
	var pre = document.createElement("pre");
	pre.style.wordWrap = "break-word";
	pre.innerHTML = message;
	output.appendChild(pre);

	$(output).scrollTop($(output)[0].scrollHeight);

}

window.addEventListener("load", init, false);

