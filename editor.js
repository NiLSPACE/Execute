
/*
	- editor.js 
	
	This file contains java scripts used to make editing files in the webadmin allot easier;
*/





// CheckCurrentLine checks in what line the selector is, and updates the info about it.
function CheckCurrentLine()
{
	var TextArea = document.getElementById("TextArea");
	var CurrentLine = 1;
	var CurrentPos = TextArea.selectionEnd;
	
	CurrentLine = TextArea.value.substring(0, TextArea.selectionEnd).split(/\r\n|\r|\n/).length;
	
	document.getElementById("CurrentLineCounter").innerHTML = "CurrentLine: " + CurrentLine;
	document.getElementById("LineCounter").innerHTML = "Num lines: " + TextArea.value.split(/\r\n|\r|\n/).length;
}





function HandleOnKeyPress(a_Event)
{
	var TextArea = document.getElementById("TextArea");
	if (a_Event.keyCode == '9') // an tab-space
	{
		var SelectionStart = TextArea.selectionStart;
		TextArea.value = TextArea.value.substring(0, SelectionStart) + "\t" + TextArea.value.substring(TextArea.selectionEnd, TextArea.value.length);
		TextArea.selectionEnd = SelectionStart + 1;
		return false;
	}
	else if (a_Event.keyCode == '13') // An enter (\n) Make sure the tab is on the same place
	{
		var Tabs = "";
		var NumTabs = 1;
		for (Idx = TextArea.selectionEnd; Idx > 0; Idx--)
		{
			if (TextArea.value.substring(Idx - 1, Idx) == "\n")
			{
				for (idx = Idx; idx < TextArea.value.length; idx++)
				{
					if (TextArea.value.substring(idx, idx + 1) == "\t")
					{
						Tabs = Tabs + "\t";
						NumTabs++;
					}
					else
					{
						break;
					}
				}
				break;
			}
		}
		var SelectionStart = TextArea.selectionStart;
		TextArea.value = TextArea.value.substring(0, SelectionStart) + "\n" + Tabs + TextArea.value.substring(TextArea.selectionEnd, TextArea.value.length);
		TextArea.selectionEnd = SelectionStart + NumTabs;
		TextArea.selectionStart = SelectionStart + NumTabs;
		window.setTimeout(CheckCurrentLine, 1);
		
		return false;
	}
	window.setTimeout(CheckCurrentLine, 1);
}




