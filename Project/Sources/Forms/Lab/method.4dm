// vCard Lab form -- dispatch only, like the Studio form. The Lab class owns
// every result so the offline checks can run without a window.

var $lab : cs.Lab

Case of
	: (FORM Event.code=On Load)
		$lab:=cs.Lab.new()
		Form.lab:=$lab
		$lab.bind(Form)

	: (FORM Event.code=On Clicked)
		If (Value type(Form.lab)=Is object)
			$lab:=Form.lab
			Case of
				: (FORM Event.objectName="presetList")
					$lab.selectPreset(Form)
				: (FORM Event.objectName="btnRun")
					$lab.selectPreset(Form)
				: (FORM Event.objectName="btnRunAll")
					$lab.runAllInto(Form)
				: (FORM Event.objectName="btnAtlas")
					$lab.atlasInto(Form)
				: (FORM Event.objectName="checkList")
					$lab.detailInto(Form)
				: (FORM Event.objectName="btnStudio")
					Demo_OpenStudio()
			End case
		End if
End case
