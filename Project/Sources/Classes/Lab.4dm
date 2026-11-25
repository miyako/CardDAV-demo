// Lab -- offline vCard laboratory and refusal catalogue.
//
// Everything here is deterministic and offline: build, parse and round-trip
// never open a socket, and the refusal catalogue records the code each layer
// returns for input the layers already reject before any network request.
//
// Layers, in call order:
//   component  cs.CardDAV.Client rejects before launching the CLI (invalid_argument)
//   cli        the bundled Go carddav validates protocol/fields (invalid_request,
//              invalid_vcard, unsupported_version, unsafe_url, ...)
//   prelaunch  _CLI refuses the target platform/architecture before spawning

property cardText : Object
property client : Object
property presets : Collection
property scenarios : Collection
property versionText : Text
property lastResult : Object

Class constructor()
	This.cardText:=cs.CardText.new()
	This.client:=cs.CardDAV.Client.new(This.target())
	This.presets:=This._presets()
	This.scenarios:=This._atlas()
	This.versionText:=""
	This.lastResult:=Null

Function target()->$target : Text
	$target:="macOS-universal"
	If (Is Windows)
		$target:="Windows-x64"
	End if
	return $target

// ------------------------------------------------------------------ presets

Function _presets()->$presets : Collection
	var $preset : Object
	$presets:=New collection

	$preset:=New object
	$preset.id:="minimal"
	$preset.name:="Minimal · 3.0"
	$preset.version:="3.0"
	$preset.note:="Only a formatted name. The builder generates a URN UUID and writes an empty structured N."
	$preset.contact:=New object("formattedName"; "Miyako Yamada")
	$presets.push($preset)

	$preset:=New object
	$preset.id:="unicode"
	$preset.name:="Japanese · 4.0"
	$preset.version:="4.0"
	$preset.note:="Non-ASCII in FN/N/ADR. Folding counts octets, not characters, so watch the audit line."
	$preset.contact:=New object
	$preset.contact.uid:="demo-unicode-0001"
	$preset.contact.formattedName:="山田 みやこ"
	$preset.contact.familyName:="山田"
	$preset.contact.givenName:="みやこ"
	$preset.contact.organization:="Example KK"
	$preset.contact.title:="Platform engineer"
	$preset.contact.emails:=New collection(New object("value"; "miyako@example.invalid"; "types"; New collection("work")))
	$preset.contact.phones:=New collection(New object("value"; "+81 90 0000 0000"; "types"; New collection("cell")))
	$preset.contact.addresses:=New collection(New object("types"; New collection("home"); "street"; "1-2-3 中央"; "locality"; "Tokyo"; "region"; "Tokyo"; "postalCode"; "100-0001"; "country"; "Japan"))
	$presets.push($preset)

	$preset:=New object
	$preset.id:="escapes"
	$preset.name:="Escapes · 4.0"
	$preset.version:="4.0"
	$preset.note:="Comma, semicolon, backslash and newline must survive a parse→raw round trip. Separators are escaped; line breaks become \\n."
	$preset.contact:=New object
	$preset.contact.uid:="demo-escapes-0001"
	$preset.contact.formattedName:="Escape Test"
	$preset.contact.note:="comma, semicolon; backslash \\ newline"+Char(10)+"and a tab"+Char(9)+"here"
	$presets.push($preset)

	$preset:=New object
	$preset.id:="folding"
	$preset.name:="Folding · 4.0"
	$preset.version:="4.0"
	$preset.note:="A 120-character Japanese name forces the builder's 75-octet fold. The physical continuation line starts with one space."
	$preset.contact:=New object
	$preset.contact.uid:="demo-folding-0001"
	$preset.contact.formattedName:="長い名前のテスト長い名前のテスト長い名前のテスト長い名前のテスト長い名前のテスト長い名前のテスト長い名前のテスト長い名前のテスト"
	$presets.push($preset)

	$preset:=New object
	$preset.id:="server"
	$preset.name:="Server card · lossless"
	$preset.version:="4.0"
	$preset.note:="A card shaped like a server response: grouped EMAIL, PHOTO, X-* property. Parsing keeps the raw Text; rebuilding from the summary cannot."
	$preset.raw:=This._serverCard()
	$presets.push($preset)

	return $presets

Function _serverCard()->$vcard : Text
	var $crlf : Text
	$crlf:=Char(13)+Char(10)
	$vcard:="BEGIN:VCARD"+$crlf+"VERSION:4.0"+$crlf
	$vcard:=$vcard+"UID:server-card-0001"+$crlf
	$vcard:=$vcard+"FN:山田 みやこ"+$crlf
	$vcard:=$vcard+"N:山田;みやこ;;;"+$crlf
	$vcard:=$vcard+"ORG:Example KK;Platform"+$crlf
	$vcard:=$vcard+"GROUP.EMAIL;TYPE=work;X-ABLabel=Office:miyako@example.invalid"+$crlf
	$vcard:=$vcard+"TEL;TYPE=cell;VALUE=text:+81 90 0000 0000"+$crlf
	$vcard:=$vcard+"PHOTO;MEDIATYPE=image/jpeg:https://example.invalid/photo.jpg"+$crlf
	$vcard:=$vcard+"X-CARDDEMO-KEEP:server-only property"+$crlf
	$vcard:=$vcard+"END:VCARD"+$crlf
	return $vcard

// Build every preset, and for the server card also rebuild from the parsed
// summary so the loss is named property by property.
Function runAll()->$rows : Collection
	var $preset : Object
	var $row : Object
	$rows:=New collection
	For each ($preset; This.presets)
		$row:=This.runPreset($preset)
		$rows.push($row)
	End for each
	return $rows

Function runPreset($preset : Object)->$row : Object
	var $result : Object
	var $audit : Object
	var $vcard : Text
	$row:=New object("id"; $preset.id; "name"; $preset.name; "note"; $preset.note; "version"; $preset.version; "ok"; False; "code"; "unknown"; "vcard"; ""; "audit"; New object; "lost"; New collection; "verdict"; "FAIL")
	If (Value type($preset.raw)=Is text)
		$result:=This.client.parse($preset.raw)
		If ($result.ok)
			$row.ok:=True
			$row.code:="ok"
			$row.vcard:=$preset.raw
			$row.lost:=This.rebuildLoss($preset.raw)
			$row.verdict:="PASS"
		Else
			$row.code:=This.code($result)
		End if
		This.lastResult:=$result
		return $row
	End if
	$result:=This.client.build($preset.contact; $preset.version)
	This.lastResult:=$result
	If ($result.ok)
		$vcard:=$result.value.vcard
		$audit:=This.cardText.audit($vcard)
		$row.ok:=True
		$row.code:="ok"
		$row.vcard:=$vcard
		$row.audit:=$audit
		$row.uid:=This.text($result.value.uid)
		$row.verdict:="PASS"
	Else
		$row.code:=This.code($result)
	End if
	return $row

// Rebuild from uid+FN only and list the properties the rebuild drops. Used by
// the server-card preset and the Studio round-trip button.
Function rebuildLoss($raw : Text)->$lost : Collection
	var $parsed : Object
	var $rebuilt : Object
	var $after : Object
	var $summary : Object
	$lost:=New collection
	$parsed:=This.client.parse($raw)
	If (Not($parsed.ok))
		return $lost
	End if
	$summary:=New object("uid"; This.text($parsed.value.uid); "formattedName"; This.text($parsed.value.formattedName))
	$rebuilt:=This.client.build($summary; "4.0")
	If (Not($rebuilt.ok))
		return $lost
	End if
	$after:=This.client.parse($rebuilt.value.vcard)
	If (Not($after.ok))
		return $lost
	End if
	$lost:=This.cardText.lostProperties($parsed.value.properties; $after.value.properties)
	return $lost

// ------------------------------------------------------------------ atlas

Function _atlas()->$scenarios : Collection
	var $scenario : Object
	var $crlf : Text
	$crlf:=Char(13)+Char(10)
	$scenarios:=New collection

	$scenario:=New object
	$scenario.id:="build-no-fn"
	$scenario.name:="Build without FN"
	$scenario.layer:="cli"
	$scenario.expect:="invalid_request"
	$scenario.note:="contact without formattedName"
	$scenario.kind:="build"
	$scenario.contact:=New object("givenName"; "NoName")
	$scenario.version:="3.0"
	$scenarios.push($scenario)

	$scenario:=New object
	$scenario.id:="build-version-2.1"
	$scenario.name:="vCard 2.1"
	$scenario.layer:="cli"
	$scenario.expect:="unsupported_version"
	$scenario.note:="only 3.0 and 4.0 exist"
	$scenario.kind:="build"
	$scenario.contact:=New object("formattedName"; "X")
	$scenario.version:="2.1"
	$scenarios.push($scenario)

	$scenario:=New object
	$scenario.id:="build-extra-field"
	$scenario.name:="Unknown contact field"
	$scenario.layer:="cli"
	$scenario.expect:="invalid_request"
	$scenario.note:="the builder is closed: photo is not a supported summary key"
	$scenario.kind:="build"
	$scenario.contact:=New object("formattedName"; "X"; "photo"; "aGk=")
	$scenario.version:="4.0"
	$scenarios.push($scenario)

	$scenario:=New object
	$scenario.id:="build-nul-uid"
	$scenario.name:="NUL in UID"
	$scenario.layer:="cli"
	$scenario.expect:="invalid_request"
	$scenario.note:="an embedded NUL is rejected, never forwarded"
	$scenario.kind:="build"
	$scenario.contact:=New object("uid"; "a"+Char(0)+"b"; "formattedName"; "X")
	$scenario.version:="3.0"
	$scenarios.push($scenario)

	$scenario:=New object
	$scenario.id:="parse-empty"
	$scenario.name:="Empty vCard"
	$scenario.layer:="cli"
	$scenario.expect:="invalid_vcard"
	$scenario.note:="no BEGIN"
	$scenario.kind:="parse"
	$scenario.vcard:=""
	$scenarios.push($scenario)

	$scenario:=New object
	$scenario.id:="parse-no-uid"
	$scenario.name:="vCard without UID"
	$scenario.layer:="cli"
	$scenario.expect:="invalid_vcard"
	$scenario.note:="UID is required in both versions"
	$scenario.kind:="parse"
	$scenario.vcard:="BEGIN:VCARD"+$crlf+"VERSION:3.0"+$crlf+"FN:Nobody"+$crlf+"END:VCARD"+$crlf
	$scenarios.push($scenario)

	$scenario:=New object
	$scenario.id:="parse-two-cards"
	$scenario.name:="Two cards in one Text"
	$scenario.layer:="cli"
	$scenario.expect:="invalid_vcard"
	$scenario.note:="one resource is one card"
	$scenario.kind:="parse"
	$scenario.vcard:="BEGIN:VCARD"+$crlf+"VERSION:3.0"+$crlf+"UID:a"+$crlf+"FN:A"+$crlf+"END:VCARD"+$crlf+"BEGIN:VCARD"+$crlf+"VERSION:3.0"+$crlf+"UID:b"+$crlf+"FN:B"+$crlf+"END:VCARD"+$crlf
	$scenarios.push($scenario)

	$scenario:=New object
	$scenario.id:="update-weak-etag"
	$scenario.name:="Weak ETag on update"
	$scenario.layer:="cli"
	$scenario.expect:="invalid_request"
	$scenario.note:="If-Match needs a strong quoted ETag"
	$scenario.kind:="update"
	$scenario.endpoint:="https://dav.example.org/"
	$scenario.vcard:=This._cardA()
	$scenario.etag:="W/\"weak\""
	$scenarios.push($scenario)

	$scenario:=New object
	$scenario.id:="update-unquoted-etag"
	$scenario.name:="Unquoted ETag"
	$scenario.layer:="cli"
	$scenario.expect:="invalid_request"
	$scenario.note:="a bare token is not a strong ETag"
	$scenario.kind:="update"
	$scenario.endpoint:="https://dav.example.org/"
	$scenario.vcard:=This._cardA()
	$scenario.etag:="plain"
	$scenarios.push($scenario)

	$scenario:=New object
	$scenario.id:="update-http-endpoint"
	$scenario.name:="Plain HTTP endpoint"
	$scenario.layer:="cli"
	$scenario.expect:="invalid_request"
	$scenario.note:="the endpoint is the HTTPS trust anchor"
	$scenario.kind:="update"
	$scenario.endpoint:="http://dav.example.org/"
	$scenario.vcard:=This._cardA()
	$scenario.etag:="\"abc\""
	$scenarios.push($scenario)

	$scenario:=New object
	$scenario.id:="discover-http"
	$scenario.name:="HTTP discovery"
	$scenario.layer:="cli"
	$scenario.expect:="invalid_request"
	$scenario.note:="the same anchor rule applies to discover"
	$scenario.kind:="discover"
	$scenario.endpoint:="http://dav.example.org/"
	$scenarios.push($scenario)

	$scenario:=New object
	$scenario.id:="discover-private"
	$scenario.name:="Private address"
	$scenario.layer:="cli"
	$scenario.expect:="unsafe_url"
	$scenario.note:="loopback and private addresses are refused before dialing, so a demo cannot point at a local mock server"
	$scenario.kind:="discover"
	$scenario.endpoint:="https://127.0.0.1/"
	$scenarios.push($scenario)

	$scenario:=New object
	$scenario.id:="request-null"
	$scenario.name:="Null request"
	$scenario.layer:="component"
	$scenario.expect:="invalid_argument"
	$scenario.note:="the component refuses before launch"
	$scenario.kind:="request-null"
	$scenarios.push($scenario)

	$scenario:=New object
	$scenario.id:="request-unknown-op"
	$scenario.name:="Unknown operation"
	$scenario.layer:="component"
	$scenario.expect:="invalid_argument"
	$scenario.note:="only the eight documented operations exist"
	$scenario.kind:="request"
	$scenario.request:=New object("operation"; "sync")
	$scenarios.push($scenario)

	$scenario:=New object
	$scenario.id:="wrong-target"
	$scenario.name:="Wrong native target"
	$scenario.layer:="prelaunch"
	$scenario.expect:="unsupported_architecture"
	$scenario.note:="the target must match the host platform; native Windows ARM64 is unsupported"
	$scenario.kind:="client"
	$scenario.target:="Windows-x64"
	$scenarios.push($scenario)

	return $scenarios

Function _cardA()->$vcard : Text
	var $crlf : Text
	$crlf:=Char(13)+Char(10)
	$vcard:="BEGIN:VCARD"+$crlf+"VERSION:4.0"+$crlf+"UID:a"+$crlf+"FN:A"+$crlf+"END:VCARD"+$crlf
	return $vcard

Function runAtlas()->$rows : Collection
	var $scenario : Object
	var $row : Object
	$rows:=New collection
	For each ($scenario; This.scenarios)
		$row:=This.runScenario($scenario)
		$rows.push($row)
	End for each
	return $rows

Function runScenario($scenario : Object)->$row : Object
	var $result : Object
	var $client : Object
	var $actual : Text
	$row:=New object("id"; $scenario.id; "name"; $scenario.name; "layer"; $scenario.layer; "expect"; $scenario.expect; "note"; $scenario.note; "actual"; "unknown"; "verdict"; "FAIL"; "message"; "")
	Case of
		: ($scenario.kind="build")
			$result:=This.client.build($scenario.contact; $scenario.version)
		: ($scenario.kind="parse")
			$result:=This.client.parse($scenario.vcard)
		: ($scenario.kind="update")
			$result:=This.client.update($scenario.endpoint; $scenario.vcard; $scenario.etag)
		: ($scenario.kind="discover")
			$result:=This.client.request(New object("operation"; "discover"; "endpoint"; $scenario.endpoint))
		: ($scenario.kind="request-null")
			$result:=This.client.request(Null)
		: ($scenario.kind="request")
			$result:=This.client.request($scenario.request)
		: ($scenario.kind="client")
			$client:=cs.CardDAV.Client.new($scenario.target)
			$result:=$client.version()
		Else
			$result:=New object("ok"; False; "error"; New object("code"; "not_implemented"; "message"; "unknown scenario kind"))
	End case
	This.lastResult:=$result
	$actual:=This.code($result)
	$row.actual:=$actual
	$row.message:=This.text($result.error.message)
	If ($actual=$scenario.expect)
		$row.verdict:="PASS"
	End if
	return $row

Function summary($rows : Collection)->$text : Text
	var $pass : Integer
	var $row : Object
	$pass:=0
	For each ($row; $rows)
		If ($row.verdict="PASS")
			$pass:=$pass+1
		End if
	End for each
	$text:=String($pass)+" of "+String($rows.length)+" expectations matched"
	return $text

// ---------------------------------------------------------------- helpers

Function code($result : Object)->$code : Text
	$code:="unknown"
	If (Value type($result)#Is object)
		return $code
	End if
	If ($result.ok)
		$code:="ok"
		return $code
	End if
	If (Value type($result.error)=Is object)
		If (Value type($result.error.code)=Is text)
			$code:=String($result.error.code)
		End if
	End if
	return $code

Function text($value : Variant)->$text : Text
	$text:=""
	If (Value type($value)=Is text)
		$text:=String($value)
	End if
	return $text

// ------------------------------------------------------------------ display
// Presentation state for the Lab form. The same methods run headlessly: they
// write plain properties into the object they are given.

Function bind($form : Object)->$bound : Object
	$form.presetRows:=This.presetRows()
	$form.checkRows:=New collection
	$form.selectedPreset:=$form.presetRows[0]
	$form.previewText:=""
	$form.auditText:=""
	$form.lossText:=""
	$form.noteText:=""
	$form.summaryText:="Lab ready · "+String(This.presets.length)+" build presets, "+String(This.scenarios.length)+" refusal scenarios"
	This.previewInto($form)
	$bound:=$form
	return $bound

Function presetRows()->$rows : Collection
	var $preset : Object
	$rows:=New collection
	For each ($preset; This.presets)
		$rows.push(New object("id"; $preset.id; "name"; $preset.name; "version"; $preset.version; "note"; $preset.note; "verdict"; "—"; "auditLine"; ""))
	End for each
	return $rows

Function selectPreset($form : Object)
	This.previewInto($form)

// Build (or parse) the selected preset and fill the preview panes.
Function previewInto($form : Object)
	var $row : Object
	var $preset : Object
	var $result : Object
	var $audit : Object
	var $lost : Collection
	var $entry : Object
	var $text : Text
	$row:=This.rowByID($form.presetRows; This.rowID($form.selectedPreset))
	If ($row=Null)
		return
	End if
	$preset:=This.presetByID($row.id)
	If ($preset=Null)
		return
	End if
	$text:=""
	$form.noteText:=$preset.note
	If (Value type($preset.raw)=Is text)
		$result:=This.client.parse($preset.raw)
		$text:=$preset.raw
		If ($result.ok)
			$form.previewText:=$text
			$form.auditText:=This.cardText.auditText(This.cardText.audit($preset.raw))
			$lost:=This.rebuildLoss($preset.raw)
			$form.lossText:="Rebuilding from the parsed summary would drop:"
			For each ($entry; $lost)
				$form.lossText:=$form.lossText+Char(13)+Char(10)+"  · "+$entry.name+"  "+$entry.value
			End for each
			$row.verdict:="PASS"
		Else
			$form.previewText:=$preset.raw
			$form.auditText:="parse refused · "+This.code($result)
			$form.lossText:=""
			$row.verdict:="FAIL"
		End if
	Else
		$result:=This.client.build($preset.contact; $preset.version)
		If ($result.ok)
			$form.previewText:=$result.value.vcard
			$audit:=This.cardText.audit($result.value.vcard)
			$form.auditText:=This.cardText.auditText($audit)
			$row.auditLine:=This.cardText.auditText($audit)
			$form.lossText:="Builder output is deterministic for " + $preset.version + " · uid " + This.text($result.value.uid)
			$row.verdict:="PASS"
		Else
			$form.previewText:=""
			$form.auditText:="build refused · "+This.code($result)
			$form.lossText:=""
			$row.verdict:="FAIL"
		End if
	End if
	$row.auditLine:=This.cardText.auditText(This.cardText.audit($form.previewText))
	This.lastResult:=$result
	$form.presetRows:=$form.presetRows

Function runAllInto($form : Object)
	var $preset : Object
	var $row : Object
	var $rows : Collection
	var $result : Object
	var $audit : Object
	var $pass : Integer
	$rows:=New collection
	For each ($preset; This.presets)
		$row:=New object("id"; $preset.id; "name"; $preset.name; "version"; $preset.version; "note"; $preset.note; "verdict"; "FAIL"; "auditLine"; "")
		If (Value type($preset.raw)=Is text)
			$result:=This.client.parse($preset.raw)
			If ($result.ok)
				$row.verdict:="PASS"
				$row.auditLine:=This.cardText.auditText(This.cardText.audit($preset.raw))
			End if
		Else
			$result:=This.client.build($preset.contact; $preset.version)
			If ($result.ok)
				$audit:=This.cardText.audit($result.value.vcard)
				$row.verdict:="PASS"
				$row.auditLine:=This.cardText.auditText($audit)
			Else
				$row.auditLine:=This.code($result)
			End if
		End if
		If ($row.verdict="PASS")
			$pass:=$pass+1
		End if
		$rows.push($row)
	End for each
	$form.presetRows:=$rows
	$form.summaryText:=String($pass)+" of "+String($rows.length)+" presets built and audited · no network"
	If (Value type($form.selectedPreset)=Is object)
		$form.selectedPreset:=$rows[0]
	End if
	This.previewInto($form)

Function atlasInto($form : Object)
	var $rows : Collection
	var $row : Object
	$rows:=This.runAtlas()
	$form.checkRows:=New collection
	For each ($row; $rows)
		$form.checkRows.push(New object("id"; $row.id; "layer"; $row.layer; "expect"; $row.expect; "actual"; $row.actual; "verdict"; $row.verdict; "note"; $row.note))
	End for each
	$form.summaryText:=This.summary($rows)+" · each call was offline and deterministic"

Function rowByID($rows : Collection; $id : Text)->$row : Object
	var $candidate : Object
	$row:=Null
	If (Value type($rows)#Is collection)
		return $row
	End if
	For each ($candidate; $rows)
		If (Value type($candidate.id)=Is text)
			If ($candidate.id=$id)
				return $candidate
			End if
		End if
	End for each
	return $row

Function rowID($row : Object)->$id : Text
	$id:=""
	If (Value type($row)=Is object)
		If (Value type($row.id)=Is text)
			$id:=String($row.id)
		End if
	End if
	return $id

Function presetByID($id : Text)->$preset : Object
	var $candidate : Object
	$preset:=Null
	If (Value type($candidate)#Is object)
		$candidate:=Null
	End if
	For each ($candidate; This.presets)
		If (Value type($candidate.id)=Is text)
			If ($candidate.id=$id)
				return $candidate
			End if
		End if
	End for each
	return $preset

Function detailInto($form : Object)
	var $row : Object
	var $text : Text
	$row:=$form.selectedCheck
	$text:=""
	If (Value type($row)=Is object)
		$text:=$row.id+" · layer "+$row.layer+Char(13)+Char(10)
		$text:=$text+"expected "+$row.expect+" · actual "+$row.actual+" · "+$row.verdict+Char(13)+Char(10)
		$text:=$text+$row.note
		If (Length(This.text($row.message))>0)
			$text:=$text+Char(13)+Char(10)+"message: "+$row.message
		End if
	End if
	$form.detailText:=$text
