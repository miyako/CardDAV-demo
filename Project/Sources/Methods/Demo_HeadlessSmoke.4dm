//%attributes = {"invisible":true}
// Demo_HeadlessSmoke -- headless acceptance for this demo.
//
// Drives cs.Studio and cs.Lab against the real component without a window and
// writes one JSON report. It exercises only offline operations: no discovery,
// query or CRUD call, so no socket is opened and no credential is needed.
//
//   tool4d --project Project/CardDAV-demo.4DProject --dataless \
//     --skip-onstartup --startup-method Demo_HeadlessSmoke \
//     --user-param '{"out":"/tmp/CardDAV-demo-smoke.json"}'
//
// The process exits 0; read "passed" in the report.
#DECLARE()

var $config; $report; $audit; $parsed : Object
var $studio : cs.Studio
var $lab : cs.Lab
var $fields; $result; $build4; $build3; $sample : Object
var $rows : Collection
var $row : Object
var $file : 4D.File
var $failures : Integer
var $text : Text
var $ok; $presetsOK; $atlasOK; $lostOK : Boolean
var $formNames; $required : Collection
ARRAY TEXT($names; 0)
ARRAY TEXT($types; 0)
var $formName; $need : Text
var $loaded; $formOK : Boolean
var $objects : Object

$config:=New object("out"; "/tmp/CardDAV-demo-smoke.json")
If (Get database parameter(User param value; $text)=0)
	$parsed:=JSON Parse($text)
	If (Value type($parsed)=Is object)
		If (Value type($parsed.out)=Is text)
			$config:=$parsed
		End if
	End if
End if

$ok:=True
$report:=New object("compiled"; Is compiled mode)

// ------------------------------------------------------------- component
$studio:=cs.Studio.new()
$lab:=cs.Lab.new()
$report.component:=New object("version"; $studio.versionText; "ok"; ($studio.versionText#""); "code"; $studio.code($studio.lastResult))
If ($studio.versionText="unavailable")
	$ok:=False
End if

// ------------------------------------------------- studio: bind + sample
$fields:=New object
$studio.bind($fields)
$report.studio:=New object
$report.studio.versionLabel:=$fields.versionText
$sample:=New object("ok"; $studio.lastResult.ok; "lossless"; $studio.losslessOK; "properties"; $studio.properties.length; "audit"; $studio.cardText.audit($fields.rawEditor))
$report.studio.sample:=$sample
If (Not($studio.losslessOK))
	$ok:=False
End if

// ------------------------------------------------------- studio: build 4.0
$build4:=New object("ok"; False; "code"; "not_run")
$result:=$studio.build($fields)
If ($result#Null)
	$audit:=$studio.cardText.audit($fields.rawEditor)
	$build4:=New object("ok"; $result.ok; "code"; $studio.code($result); "audit"; $audit)
	$build4.vcard:=$fields.rawEditor
	$build4.crlfOk:=($audit.crlfCount>0) & ($audit.bareLfCount=0)
	$build4.foldingOk:=($audit.linesOver75=0)
	$build4.escapedComma:=(Position("\\,"; $fields.rawEditor; 1; *)>0)
	$build4.escapedSemicolon:=(Position("\\;"; $fields.rawEditor; 1; *)>0)
	$build4.escapedNewline:=(Position("\\n"; $fields.rawEditor; 1; *)>0)
	If ((Not($result.ok)) | (Not($build4.crlfOk)) | (Not($build4.foldingOk)) | (Not($build4.escapedNewline)))
		$ok:=False
	End if
	If ($studio.properties.length<5)
		$ok:=False
	End if
Else
	$ok:=False
End if
$report.studio.build4:=$build4

// ------------------------------------------------------- studio: build 3.0
$build3:=New object("ok"; False; "code"; "not_run")
$result:=$lab.client.build(New object("formattedName"; "Miyako Yamada"); "3.0")
If ($result.ok)
	$build3:=New object("ok"; True; "code"; "ok"; "uid"; $result.value.uid; "generatedUID"; (Position("URN:UUID:"; Uppercase($result.value.vcard); 1; *)>0); "emptyStructuredN"; (Position("N:;;;;"; $result.value.vcard; 1; *)>0))
	If ((Not($build3.generatedUID)) | (Not($build3.emptyStructuredN)))
		$ok:=False
	End if
Else
	$build3:=New object("ok"; False; "code"; $lab.code($result))
	$ok:=False
End if
$report.studio.build3:=$build3

// -------------------------------------------------- studio: round-trip loss
$studio.seedServerCard($fields)
$result:=$studio.roundTrip($fields)
$report.studio.roundTrip:=New object("ok"; False; "code"; "not_run"; "fidelity"; $studio.fidelityText; "status"; $studio.statusText; "envelope"; $studio.envelopeText)
If ($result#Null)
	$report.studio.roundTrip:=New object("ok"; $result.ok; "code"; $studio.code($result); "fidelity"; $studio.fidelityText; "lostNamed"; (Position("Dropped by rebuilding"; $studio.fidelityText; 1; *)>0))
	If ((Not($result.ok)) | (Not($report.studio.roundTrip.lostNamed)))
		$ok:=False
	End if
Else
	$ok:=False
End if

// ---------------------------------------------------------------- lab runs
$rows:=$lab.runAll()
$report.lab:=New object("presets"; New collection)
$presetsOK:=True
$lostOK:=False
For each ($row; $rows)
	$report.lab.presets.push(New object("id"; $row.id; "verdict"; $row.verdict; "code"; $row.code; "audit"; $row.audit; "lost"; $row.lost))
	If ($row.verdict#"PASS")
		$presetsOK:=False
	End if
	If (($row.id="server") & ($row.lost.length>0))
		$lostOK:=True
	End if
End for each
If ((Not($presetsOK)) | (Not($lostOK)))
	$ok:=False
End if
$report.lab.presetCount:=$rows.length

$rows:=$lab.runAtlas()
$report.lab.atlas:=New collection
$atlasOK:=True
$failures:=0
For each ($row; $rows)
	$report.lab.atlas.push(New object("id"; $row.id; "layer"; $row.layer; "expect"; $row.expect; "actual"; $row.actual; "message"; $row.message; "verdict"; $row.verdict))
	If ($row.verdict#"PASS")
		$atlasOK:=False
		$failures:=$failures+1
	End if
End for each
If (Not($atlasOK))
	$ok:=False
End if
$report.lab.summary:=$lab.summary($rows)
$report.lab.failureCount:=$failures
$report.lab.allMatched:=$atlasOK

// ------------------------------------------------------------------- forms
// The .4DForm JSON is only real if 4D can load it and sees the objects the form
// methods dispatch on. Bind is exercised above; this checks the layout half.
$report.forms:=New object
For each ($formName; New collection("Studio"; "Lab"))
	$loaded:=False
	<>SmokeErrorText:=""
	ON ERR CALL("Demo_SmokeOnErr"; ek local)
	FORM LOAD($formName)
	$loaded:=(<>SmokeErrorText="")
	ON ERR CALL(""; ek local)
	$formOK:=$loaded
	$objects:=New object("error"; <>SmokeErrorText)
	If ($loaded)
		FORM GET OBJECTS($names; $types)
		$objects.objects:=Size of array($names)
		$required:=New collection
		If ($formName="Studio")
			$required:=New collection("endpoint"; "btnDiscover"; "btnProbe"; "bookList"; "contactList"; "rawEditor"; "btnRoundTrip"; "btnCreate"; "btnUpdate"; "btnDelete"; "envelopeText"; "parseText"; "notesText"; "statusText"; "auditText"; "fidelityText")
		Else
			$required:=New collection("presetList"; "checkList"; "btnRunAll"; "btnAtlas"; "btnRun"; "btnStudio"; "previewView"; "lossView"; "detailView"; "summaryText")
		End if
		$objects.missing:=New collection
		For each ($need; $required)
			If (Find in array($names; $need)<1)
				$objects.missing.push($need)
				$formOK:=False
			End if
		End for each
		FORM UNLOAD
	End if
	$objects.ok:=$formOK
	$report.forms[$formName]:=$objects
	If (Not($formOK))
		$ok:=False
	End if
End for each

$report.passed:=$ok & ($failures=0)
$report.offlineOnly:=True

$file:=File($config.out)
$file.parent.create()
$file.setText(JSON Stringify($report; *))
QUIT 4D
