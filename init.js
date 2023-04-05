
/*
	- init.js 
	
	This file contains javascript used to make editing files in the webadmin allot easier;
*/





// Initialize the Ace editor with Lua as the set language.
let editor = ace.edit("editor", {
	useWorker: false,
	showLineNumbers: true
});
editor.session.setMode("ace/mode/lua");




let lastOpenedFile = null;
let pollId;
let outputDom = document.getElementById("output");
let dropdownDom = document.getElementById("drop-down");
let logDom = document.getElementById("logs");


// Serializes an object to post as application/x-www-form-urlencoded.
const serialize = function(obj) {
	let str = [];
	for (let p in obj)
	if (obj.hasOwnProperty(p)) {
		str.push(encodeURIComponent(p) + "=" + encodeURIComponent(obj[p]));
	}
	return str.join("&");
}





/*
	Puts a new message in the logDom.
	If the logDom is empty it also creates an anhor to empty it again.
 */
function log(msg, color) {
	if (logDom.innerText == '') {
		let clearBtn = document.createElement("a");
		clearBtn.href = "#"
		clearBtn.innerText = "Clear"
		clearBtn.addEventListener("click", () => logDom.innerText = '');
		logDom.appendChild(clearBtn);
	}
	
	let b = document.createElement("b");
	b.innerText = msg;
	b.style.color = color;
	logDom.appendChild(b);
}




/*
	Turns the list of logs into dom objects and appends them to outputDom.
 */
function appendOutput(logs) {
	for (let msg of logs || []) {
		let log = document.createElement("b");
		log.classList.add(msg.type);
		let text = ''
		if (msg.type != 'print') {
			text = "[" + msg.time + "] ";
		}
		log.innerText = text + msg.message
		outputDom.appendChild(log);
	}
}





/*
	Sends the code in the editor to the server to be executed.
	Expects a list of message as a response and puts those in the outputDom.
 */
async function execute(event) {
	if (pollId) {
		clearInterval(pollId)
	}
		
	event.target.disabled = "disabled"
	let response = await fetch("/~webadmin/Executor/Execute+Lua?endpoint=execute", {
		method: "POST",
		headers: {
			"Content-Type": "application/x-www-form-urlencoded"
		},
		body: serialize({
			Execute: true,
			LuaScript: editor.session.getValue()
		})
	});
	
	let content = await response.json();
	outputDom.innerText = '';
	appendOutput(content.logs);
	
	pollId = setInterval(async() => {
		let numLogs = outputDom.children.length + 1;
		let response = await fetch(`/~webadmin/Executor/Execute+Lua?endpoint=poll&exec-id=${content.execId}&last-msg=${numLogs}`)
		if (response.headers.get("content-type") == "error") {
			// Some kind of error occured. This can happen if the server reloaded and the execId isn't recognized anymore.
			clearInterval(pollId);
			return;
		}
		let logs = await response.json();
		appendOutput(logs);
	}, 500)
	
	event.target.disabled = ""
}




/*
	Helper function to create an element and use a callback to modify it.
 */
function createElement(type, finalizer) {
	let elem = document.createElement(type);
	finalizer(elem);
	return elem;
}





/*
	Button callback called when the user opens a file.
	Retrieves the file from the server and sets it in the editor.
 */
async function openFile(event) {
	let filename = event.target.dataset.file;
	lastOpenedFile = filename;
	let request = await fetch("/~webadmin/Executor/Execute+Lua?endpoint=get-file&file=" + filename)
	let code = await request.text();
	if (request.headers.get('content-type') == 'error') {
		log(code, "red");
		return;
	}
	editor.session.setValue(code);
}





/*
	Button callback called when a user deletes a file.
	Sends a request to the server to delete the file.
	Uses a 'confirm' to prevent accidental deletion.
 */
async function deleteFile(event) {
	let filename = event.target.dataset.file;
	
	if (!confirm(`Are you sure you want to delete ${filename}?`)) {
		return
	}
	
	let request = await fetch("/~webadmin/Executor/Execute+Lua?endpoint=delete-file", {
		method: "POST",
		headers: {
			"Content-Type": "application/x-www-form-urlencoded"
		},
		body: serialize({
			"delete-file": filename
		})
	});
	
	if (request.headers.get("content-type") != 'error') {
		event.target.parentElement.parentElement.remove();
	} else {
		let response = await request.text();
		log(response, "red");
	}
}





/*
	Empties the dropdown div and modifies it status to closed.
 */
function closeDropDown() {
	dropdownDom.innerText = '';
	dropdownDom.dataset.status = "closed";
}





/*
	Fills the dropdown with a list of all script files on the server.
	Adds buttons to open or delete said files.
 */
async function listFilesDropDown() {
	if (dropdownDom.dataset.status == "list-files") {
		closeDropDown();
	}
	else {
		dropdownDom.innerText = '';
		let response = await fetch("/~webadmin/Executor/Execute+Lua?endpoint=get-file-list");
		let files = await response.json();
		let table = document.createElement("table");
		table.appendChild(createElement("tr", tr => {
			tr.appendChild(createElement("th", th => {
				th.innerText = 'File'
				th.setAttribute('colspan', 3)
			}))
		}))
		for (let file of files) {
			let tr = document.createElement("tr");
			tr.appendChild(createElement("td", td => td.innerText = file));
			tr.appendChild(createElement("td", td => {
				td.appendChild(createElement("button", button => {
					button.dataset.file = file
					button.addEventListener('click', openFile);
					button.innerText = 'Open'
				}))
			}))
			tr.appendChild(createElement("td", td => {
				td.appendChild(createElement("button", button => {
					button.dataset.file = file
					button.addEventListener('click', deleteFile);
					button.innerText = 'Delete'
				}))
			}))
			table.appendChild(tr);
		}
		
		dropdownDom.appendChild(table);
		dropdownDom.dataset.status = "list-files";
	}
}





/*
	Sends a request  to the server to save a file with the content of everything in the editor.
 */
async function saveFile(event, filename) {
	if (!filename.endsWith(".lua")) {
		filename += ".lua"
	}
	let request = await fetch("/~webadmin/Executor/Execute+Lua?endpoint=save-file", {
		method: "POST",
		headers: {
			'Content-Type': "application/x-www-form-urlencoded"
		},
		body: serialize({
			file: filename,
			code: editor.session.getValue()
		})
	});
	
	let response = await request.text();
	if (response == "ok") {
		closeDropDown();
		lastOpenedFile = filename
		log("File saved", "green");
	}
	else {
		log(response, "red");
	}
	
}





/*
	Fills the dropdown with an input box and a button to actually save the file.
 */
function saveFileDropDown() {
	if (dropdownDom.dataset.status == "save-file") {
		closeDropDown();
	}
	else {
		dropdownDom.innerText = '';
		
		let div = document.createElement("div");
		let input = document.createElement("input");
		input.value = lastOpenedFile;
		input.placeholder = "filename"
		let button = document.createElement("button");
		button.innerText = 'Save';
		button.addEventListener("click", (event) => saveFile(event, input.value));
		
		div.appendChild(input);
		div.appendChild(button);
		dropdownDom.appendChild(div);
		dropdownDom.dataset.status = "save-file";
	}
}




