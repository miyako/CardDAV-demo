// Studio form -- dispatch only. Behaviour lives in cs.Studio so the same code
// runs headlessly (Demo_HeadlessSmoke) and from the window.
//
// The form never checks its own name: headless runs have no form.

var $scene : cs.Studio
var $clicked : Text

Case of
	: (FORM Event.code=On Load)
		$scene:=cs.Studio.new()
		Form.scene:=$scene
		$scene.bind(Form)

	: (FORM Event.code=On Clicked)
		If (Value type(Form.scene)=Is object)
			$scene:=Form.scene
			$clicked:=FORM Event.objectName
			Case of
				: ($clicked="btnDiscover")
					$scene.discover(Form)
				: ($clicked="btnProbe")
					$scene.probeAnonymous(Form)
				: ($clicked="btnQuery")
					$scene.query(Form)
				: ($clicked="btnBuild")
					$scene.build(Form)
				: ($clicked="btnParse")
					$scene.parseRaw(Form)
				: ($clicked="btnRoundTrip")
					$scene.roundTrip(Form)
				: ($clicked="btnSeed")
					$scene.seedServerCard(Form)
				: ($clicked="bookList")
					$scene.selectBook(Form; Form.selectedBook)
				: ($clicked="contactList")
					$scene.selectContact(Form; Form.selectedContact)
				: ($clicked="btnGet")
					$scene.get(Form)
				: ($clicked="btnCreate")
					$scene.create(Form)
				: ($clicked="btnUpdate")
					$scene.update(Form)
				: ($clicked="btnDelete")
					$scene.delete(Form)
			End case
		End if
End case
