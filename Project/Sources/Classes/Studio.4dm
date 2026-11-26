// Studio -- CardDAV connection workbench state.
//
// The form owns pixels; this class owns the component. Every method takes the
// form object, so Demo_HeadlessSmoke can drive the exact same code with a plain
// object and no window.
//
// Two groups of behaviour, deliberately separated:
//   offline  build / parse / round-trip -- call the bundled Go CLI, no network
//   live     discover / query / get / create / update / delete -- verified TLS,
//            explicit HTTPS trust anchor, no credential storage
//
// A live method never invents success: the component envelope is shown as-is,
// including the CLI's own error code (conflict, authentication_failed, ...).

property client : Object
property versionText : Text
property statusText : Text
property envelopeText : Text
property discoveryText : Text
property parseText : Text
property auditText : Text
property fidelityText : Text
property books : Collection
property contacts : Collection
property properties : Collection
property losslessOK : Boolean
property cardText : Object
property lastResult : Object

// The public probe endpoint. It is a real HTTPS CardDAV server that answers
// anonymous discovery with 401, which is exactly the refusal worth showing.
property PUBLIC_PROBE : Text

Class constructor()
	This.PUBLIC_PROBE:="https://contacts.icloud.com/"
	This.cardText:=cs.CardText.new()
	This.client:=cs.CardDAV.Client.new(This.target())
	This.versionText:="unknown"
	This.statusText:=""
	This.envelopeText:="{ }"
	This.discoveryText:=""
	This.parseText:=""
	This.auditText:=""
	This.fidelityText:=""
	This.books:=New collection
	This.contacts:=New collection
	This.properties:=New collection
	This.losslessOK:=False
	This.lastResult:=Null
	This.probe()

// An explicit target: the component requires it on Windows and accepts it on
// macOS, so the demo never depends on an implicit default.
Function target()->$target : Text
	$target:="macOS-universal"
	If (Is Windows)
		$target:="Windows-x64"
	End if
	return $target

// Read-only version probe. It launches the CLI with --version but opens no
// network connection.
Function probe()
	var $result : Object
	$result:=This.client.version()
	This.lastResult:=$result
	This.envelopeText:=This.envelope($result)
	If ($result.ok)
		This.versionText:=This._text($result.value.version)
		This.statusText:="component "+This.versionText+" · offline build/parse ready · live requires an endpoint"
	Else
		This.versionText:="unavailable"
		This.statusText:="version failed · "+This.code($result)
	End if

// Starter values. The raw editor starts with a server-shaped card (grouped
// EMAIL, PHOTO, X-* property) because that is the card a rebuild cannot keep.
Function bind($form : Object)->$bound : Object
	$form.endpoint:=""
	$form.username:=""
	$form.password:=""
	$form.bookURL:=""
	$form.filterProperty:=""
	$form.matchType:="contains"
	$form.filterText:=""
	$form.limit:=100
	$form.url:=""
	$form.etag:=""
	$form.versionChoice:="4.0"
	$form.formattedName:="山田 みやこ"
	$form.familyName:="山田"
	$form.givenName:="みやこ"
	$form.organization:="Example KK"
	$form.title:="Platform engineer"
	$form.note:="Line one"+Char(10)+"Line two, with a comma; a semicolon and a \\ backslash"
	$form.email:="miyako@example.invalid"
	$form.phone:="+81 90 0000 0000"
	$form.rawEditor:=This.sampleCard()
	$form.notesText:=This.notes()
	This._parseInto($form; $form.rawEditor)
	This.auditText:=This.cardText.auditText(This.cardText.audit($form.rawEditor))
	This.refresh($form)
	$bound:=$form
	return $bound

Function notes()->$text : Text
	$text:="LIVE — discovery, query and CRUD talk to a real CardDAV server over verified TLS. Credentials live in memory only: never written, logged or passed on a command line."+Char(13)+Char(10)+Char(13)+Char(10)
	$text:=$text+"ANONYMOUS PROBE — one discover against a public endpoint with no credentials. The refusal it returns is real network evidence, not a mock."+Char(13)+Char(10)+Char(13)+Char(10)
	$text:=$text+"OFFLINE — build, parse and round-trip run the bundled CLI with no socket, so those lessons need no server."+Char(13)+Char(10)+Char(13)+Char(10)
	$text:=$text+"ETAG — create is conditional on absence; update and delete need the current strong ETag. A stale ETag returns conflict, never an overwrite."+Char(13)+Char(10)+Char(13)+Char(10)
	$text:=$text+"LOSSLESS — the raw editor text is exactly what update sends. A rebuilt card keeps uid and FN only: PHOTO, grouped properties and X-* properties are gone."
	return $text

// A vCard a real server may hand back: grouped property, parameters, a PHOTO
// URL, an unknown X-* property, a folded long line.
Function sampleCard()->$vcard : Text
	var $crlf : Text
	$crlf:=Char(13)+Char(10)
	$vcard:="BEGIN:VCARD"+$crlf
	$vcard:=$vcard+"VERSION:4.0"+$crlf
	$vcard:=$vcard+"UID:server-card-0001"+$crlf
	$vcard:=$vcard+"FN:山田 みやこ"+$crlf
	$vcard:=$vcard+"N:山田;みやこ;;;"+$crlf
	$vcard:=$vcard+"ORG:Example KK;Platform"+$crlf
	$vcard:=$vcard+"GROUP.EMAIL;TYPE=work;X-ABLabel=Office:miyako@example.invalid"+$crlf
	$vcard:=$vcard+"TEL;TYPE=cell;VALUE=text:+81 90 0000 0000"+$crlf
	$vcard:=$vcard+"PHOTO;MEDIATYPE=image/jpeg:https://example.invalid/photo.jpg"+$crlf
	$vcard:=$vcard+"X-CARDDEMO-KEEP:this property only exists on the server card"+$crlf
	$vcard:=$vcard+"NOTE:Two lines\\nand a comma\\, a semicolon\\; and a backslash \\\\"+$crlf
	$vcard:=$vcard+"END:VCARD"+$crlf
	return $vcard

// Push derived state into the form. Editable fields are never overwritten here:
// only actions that read them may write them.
Function refresh($form : Object)
	$form.versionText:="CardDAV "+This.versionText
	$form.statusText:=This.statusText
	$form.envelopeText:=This.envelopeText
	$form.discoveryText:=This.discoveryText
	$form.parseText:=This.parseText
	$form.auditText:=This.auditText
	$form.fidelityText:=This.fidelityText
	$form.bookRows:=This.books
	$form.contactRows:=This.contacts

// ---------------------------------------------------------------- offline

Function build($form : Object)->$result : Object
	var $contact : Object
	$result:=Null
	If (Length($form.formattedName)=0)
		This.statusText:="nothing to build · fill at least the formatted name"
		This.refresh($form)
		return $result
	End if
	$contact:=This.contactFrom($form)
	$result:=This.client.build($contact; $form.versionChoice)
	This.lastResult:=$result
	This.envelopeText:=This.envelope($result)
	If ($result.ok)
		$form.rawEditor:=$result.value.vcard
		$form.url:=""
		$form.etag:=""
		This.auditText:=This.cardText.auditText(This.cardText.audit($form.rawEditor))
		This._parseInto($form; $form.rawEditor)
		This.statusText:="built "+This._text($result.value.version)+" · uid "+This._text($result.value.uid)+" · "+This.auditText
	Else
		This.statusText:="build refused · "+This.code($result)
	End if
	This.refresh($form)
	return $result

// Parse the editor content and keep the properties for display. Does not touch
// the envelope: build()/parseRaw() decide what the console shows.
Function _parseInto($form : Object; $vcard : Text)
	var $result : Object
	var $property : Object
	var $text; $label : Text
	$result:=This.client.parse($vcard)
	If (Not($result.ok))
		This.properties:=New collection
		This.parseText:="parse failed · "+This.code($result)+Char(13)+Char(10)+This._text($result.error.message)
		This.losslessOK:=False
		return
	End if
	This.properties:=$result.value.properties
	This.losslessOK:=This.cardText.sameText($result.value.vcard; $vcard)
	$text:="uid "+This._text($result.value.uid)+" · version "+This._text($result.value.version)+" · "+String(This.properties.length)+" properties"
	If (This.losslessOK)
		$text:=$text+" · raw Text unchanged"+Char(13)+Char(10)
	Else
		$text:=$text+" · raw Text CHANGED"+Char(13)+Char(10)
	End if
	For each ($property; This.properties)
		$label:=This._text($property.name)
		If (Length(This._text($property.group))>0)
			$label:=This._text($property.group)+"."+$label
		End If
		$text:=$text+$label+" : "+This._text($property.value)+Char(13)+Char(10)
	End for each
	This.parseText:=$text
	This.fidelityText:="Lossless check: the component returns the raw Text you sent, byte for byte. Rebuilding from these " + String(This.properties.length) + " parsed properties is a different, lossy operation: press Round-trip to see which properties a rebuild drops."

Function parseRaw($form : Object)->$result : Object
	$result:=This.client.parse($form.rawEditor)
	This.lastResult:=$result
	This.envelopeText:=This.envelope($result)
	This._parseInto($form; $form.rawEditor)
	This.auditText:=This.cardText.auditText(This.cardText.audit($form.rawEditor))
	If ($result.ok)
		This.statusText:="parsed "+String(This.properties.length)+" properties · raw preservation "+This._boolText(This.losslessOK)
	Else
		This.statusText:="parse refused · "+This.code($result)
	End if
	This.refresh($form)
	return $result

// Build a new card from the summary fields parse() exposes (uid + FN) and name
// every property the rebuild could not keep. This is the demo's central lesson:
// use raw Text for CRUD, never a rebuilt card.
Function roundTrip($form : Object)->$result : Object
	var $before : Object
	var $summary : Object
	var $rebuilt : Object
	var $after : Object
	var $lost : Collection
	var $entry : Object
	var $text : Text
	$result:=Null
	$before:=This.client.parse($form.rawEditor)
	If (Not($before.ok))
		This.envelopeText:=This.envelope($before)
		This.statusText:="round-trip needs a parsable card first · "+This.code($before)
		This.refresh($form)
		return $result
	End if
	$summary:=New object("uid"; This._text($before.value.uid); "formattedName"; This._text($before.value.formattedName))
	$rebuilt:=This.client.build($summary; $form.versionChoice)
	This.lastResult:=$rebuilt
	This.envelopeText:=This.envelope($rebuilt)
	If (Not($rebuilt.ok))
		This.fidelityText:="rebuild refused · "+This.code($rebuilt)
		This.statusText:="round-trip rebuild refused · "+This.code($rebuilt)
		This.refresh($form)
		return $result
	End if
	$after:=This.client.parse($rebuilt.value.vcard)
	If (Not($after.ok))
		This.fidelityText:="rebuilt card did not parse · "+This.code($after)
		This.statusText:="round-trip check incomplete · "+This.code($after)
		This.refresh($form)
		return $result
	End if
	$lost:=This.cardText.lostProperties($before.value.properties; $after.value.properties)
	$text:="rebuild keeps uid + FN = "+String($after.value.properties.length)+" of "+String($before.value.properties.length)+" properties."
	$text:=$text+Char(13)+Char(10)
	If ($lost.length=0)
		$text:=$text+"No property was lost for this card."
	Else
		$text:=$text+"Dropped by rebuilding:"
		For each ($entry; $lost)
			$text:=$text+Char(13)+Char(10)+"  · "+$entry.name+"  "+$entry.value
		End for each
	End if
	This.fidelityText:=$text
	If ($lost.length=1)
		This.statusText:="round-trip dropped 1 property"
	Else
		This.statusText:="round-trip dropped "+String($lost.length)+" properties"
	End if
	This.refresh($form)
	return $rebuilt

// Restore the server-shaped sample card and re-audit it.
Function seedServerCard($form : Object)
	$form.rawEditor:=This.sampleCard()
	$form.url:=""
	$form.etag:=""
	This._parseInto($form; $form.rawEditor)
	This.auditText:=This.cardText.auditText(This.cardText.audit($form.rawEditor))
	This.envelopeText:="{ }"
	This.statusText:="server card restored · "+This.auditText
	This.refresh($form)

// ---------------------------------------------------------------- live

Function discover($form : Object)->$result : Object
	var $client : Object
	var $book : Object
	var $books : Collection
	var $home : Text
	$result:=Null
	$client:=This.connection($form)
	If ($client=Null)
		This.statusText:=This.connectionProblem($form)
		This.refresh($form)
		return $result
	End if
	$result:=$client.discover()
	This.lastResult:=$result
	This.envelopeText:=This.envelope($result)
	If ($result.ok)
		$books:=New collection
		For each ($book; $result.value.addressbooks)
			$books.push(New object("displayName"; This._text($book.displayName); "url"; This._text($book.url); "versions"; This._join($book.supportedVersions)))
		End for each
		This.books:=$books
		$home:=This._join($result.value.homeURLs)
		This.discoveryText:="principal "+This._text($result.value.principalURL)+Char(13)+Char(10)+"home "+$home+Char(13)+Char(10)+String($books.length)+" address book(s)"
		If ($books.length>0)
			$form.bookURL:=$books[0].url
			This.statusText:="discovered "+String($books.length)+" address book(s) · first book selected"
		Else
			This.statusText:="discovery succeeded, but the server advertises no address book"
		End if
	Else
		This.books:=New collection
		This.discoveryText:="discovery refused · "+This.code($result)
		This.statusText:="discover failed · "+This.code($result)+" · "+This._text($result.error.message)
	End if
	This.refresh($form)
	return $result

// Real anonymous HTTPS probe: one discover against a public endpoint with no
// credentials. The refusal is the evidence; nothing is stored.
Function probeAnonymous($form : Object)->$result : Object
	var $client : Object
	$result:=Null
	$client:=cs.CardDAV.Client.new(This.target())
	$result:=$client.request(New object("operation"; "discover"; "endpoint"; This.PUBLIC_PROBE))
	This.lastResult:=$result
	This.envelopeText:=This.envelope($result)
	This.books:=New collection
	If ($result.ok)
		This.discoveryText:="anonymous probe unexpectedly succeeded"
		This.statusText:="anonymous probe succeeded · credentialed servers should refuse this"
	Else
		This.discoveryText:="anonymous probe of "+This.PUBLIC_PROBE+Char(13)+Char(10)+"refused with "+This.code($result)+": "+This._text($result.error.message)
		This.statusText:="anonymous probe ← "+This.code($result)+" (this is the expected refusal)"
	End if
	This.refresh($form)
	return $result

Function selectBook($form : Object; $row : Object)
	If (Value type($row)#Is object)
		return
	End if
	If (Value type($row.url)=Is text)
		$form.bookURL:=String($row.url)
		This.statusText:="book URL copied to the query field"
	End if
	This.refresh($form)

Function query($form : Object)->$result : Object
	var $client : Object
	var $options : Object
	var $filter : Object
	var $contact : Object
	var $rows : Collection
	var $name : Text
	$result:=Null
	$client:=This.connection($form)
	If ($client=Null)
		This.statusText:=This.connectionProblem($form)
		This.refresh($form)
		return $result
	End if
	If (Length($form.bookURL)=0)
		This.statusText:="discover first, or paste the address book URL"
		This.refresh($form)
		return $result
	End if
	$options:=New object("limit"; This._int($form.limit))
	If (Length($form.filterText)>0)
		$filter:=New object("property"; $form.filterProperty; "text"; $form.filterText; "matchType"; $form.matchType)
		If (Length($form.filterProperty)=0)
			$filter.property:="FN"
		End if
		$options.filter:=$filter
	End if
	$result:=$client.query($form.bookURL; $options)
	This.lastResult:=$result
	This.envelopeText:=This.envelope($result)
	If ($result.ok)
		$rows:=New collection
		For each ($contact; $result.value.contacts)
			$name:=This._text($contact.etag)
			If (Length($name)>18)
				$name:=Substring($name; 1; 18)+"…"
			End if
			$rows.push(New object("url"; This._text($contact.url); "etag"; This._text($contact.etag); "vcard"; This._text($contact.vcard); "name"; This.cardName(This._text($contact.vcard)); "shortETag"; $name; "version"; This.cardVersion(This._text($contact.vcard))))
		End for each
		This.contacts:=$rows
		This.statusText:="query returned "+String($rows.length)+" contact(s) · complete="+This._boolText($result.value.complete)
	Else
		This.contacts:=New collection
		This.statusText:="query failed · "+This.code($result)
	End if
	This.refresh($form)
	return $result

Function selectContact($form : Object; $row : Object)
	If (Value type($row)#Is object)
		return
	End if
	$form.url:=$row.url
	$form.etag:=$row.etag
	$form.rawEditor:=$row.vcard
	This._parseInto($form; $form.rawEditor)
	This.auditText:=This.cardText.auditText(This.cardText.audit($form.rawEditor))
	This.statusText:="contact loaded into the raw editor · GET again to refresh its ETag"
	This.refresh($form)

Function get($form : Object)->$result : Object
	var $client : Object
	$result:=Null
	$client:=This.connection($form)
	If ($client=Null)
		This.statusText:=This.connectionProblem($form)
		This.refresh($form)
		return $result
	End if
	$result:=$client.get($form.url)
	This._liveEnvelope($form; $result)
	If ($result.ok)
		$form.rawEditor:=$result.value.vcard
		$form.etag:=This._text($result.value.etag)
		$form.url:=This._text($result.value.url)
		This._parseInto($form; $form.rawEditor)
		This.auditText:=This.cardText.auditText(This.cardText.audit($form.rawEditor))
		This.statusText:="GET ok · etag "+$form.etag
	End if
	This.refresh($form)
	return $result

Function create($form : Object)->$result : Object
	var $client : Object
	$result:=Null
	$client:=This.connection($form)
	If ($client=Null)
		This.statusText:=This.connectionProblem($form)
		This.refresh($form)
		return $result
	End if
	If (Length($form.url)=0)
		This.statusText:="create needs the resource URL (not a collection URL)"
		This.refresh($form)
		return $result
	End if
	$result:=$client.create($form.url; $form.rawEditor)
	This._liveEnvelope($form; $result)
	If ($result.ok)
		$form.url:=This._text($result.value.url)
		$form.etag:=This._text($result.value.etag)
		This.statusText:="created · If-None-Match:* succeeded · etag "+$form.etag
	End if
	This.refresh($form)
	return $result

Function update($form : Object)->$result : Object
	var $client : Object
	$result:=Null
	$client:=This.connection($form)
	If ($client=Null)
		This.statusText:=This.connectionProblem($form)
		This.refresh($form)
		return $result
	End if
	$result:=$client.update($form.url; $form.rawEditor; $form.etag)
	This._liveEnvelope($form; $result)
	If ($result.ok)
		$form.etag:=This._text($result.value.etag)
		This.statusText:="updated · If-Match matched · new etag "+$form.etag
	Else
		If (This.code($result)="conflict")
			This.statusText:="update refused: stale ETag (412 conflict). GET the contact again before retrying."
		End if
	End if
	This.refresh($form)
	return $result

Function delete($form : Object)->$result : Object
	var $client : Object
	$result:=Null
	$client:=This.connection($form)
	If ($client=Null)
		This.statusText:=This.connectionProblem($form)
		This.refresh($form)
		return $result
	End if
	$result:=$client.delete($form.url; $form.etag)
	This._liveEnvelope($form; $result)
	If ($result.ok)
		$form.etag:=""
		This.statusText:="deleted · If-Match matched"
	End if
	This.refresh($form)
	return $result

// ---------------------------------------------------------------- helpers

Function connection($form : Object)->$client : Object
	var $credentials : Object
	$client:=Null
	If (Length($form.endpoint)=0)
		return $client
	End if
	$credentials:=New object("endpoint"; $form.endpoint)
	If ((Length($form.username)>0) | (Length($form.password)>0))
		If ((Length($form.username)=0) | (Length($form.password)=0))
			// Half a credential must not quietly become an anonymous call.
			return $client
		End if
		$credentials.username:=$form.username
		$credentials.password:=$form.password
	End if
	$client:=cs.CardDAV.Client.new(This.target(); $credentials)
	return $client

// Why connection() returned Null.
Function connectionProblem($form : Object)->$text : Text
	$text:="enter an endpoint first, e.g. https://dav.example.org/"
	If (Length($form.endpoint)>0)
		$text:="enter both username and password, or clear both for an anonymous call"
	End if

Function contactFrom($form : Object)->$contact : Object
	$contact:=New object
	If (Length($form.formattedName)>0)
		$contact.formattedName:=$form.formattedName
	End if
	If (Length($form.familyName)>0)
		$contact.familyName:=$form.familyName
	End if
	If (Length($form.givenName)>0)
		$contact.givenName:=$form.givenName
	End if
	If (Length($form.organization)>0)
		$contact.organization:=$form.organization
	End if
	If (Length($form.title)>0)
		$contact.title:=$form.title
	End if
	If (Length($form.note)>0)
		$contact.note:=$form.note
	End if
	If (Length($form.email)>0)
		$contact.emails:=New collection(New object("value"; $form.email; "types"; New collection("work"; "pref")))
	End if
	If (Length($form.phone)>0)
		$contact.phones:=New collection(New object("value"; $form.phone; "types"; New collection("cell")))
	End if
	return $contact

// The CLI's own error code, or "ok" for a success envelope.
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

// One console block: verdict, code, exit code, then the untouched streams.
Function envelope($result : Object)->$text : Text
	var $out; $err : Text
	If (Value type($result)#Is object)
		return "(no result object)"
	End if
	$text:="ok="+String($result.ok)
	If (Not($result.ok))
		If (Value type($result.error)=Is object)
			$text:=$text+" · code="+This._text($result.error.code)
			$text:=$text+" · "+This._text($result.error.message)
		End if
	End if
	If ((Value type($result.exitCode)=Is longint) | (Value type($result.exitCode)=Is real))
		$text:=$text+" · exit="+String(Num($result.exitCode))
	End if
	$text:=$text+Char(13)+Char(10)+"── stdout ──"+Char(13)+Char(10)+This._text($result.stdout)
	$text:=$text+Char(13)+Char(10)+"── stderr ──"+Char(13)+Char(10)+This._text($result.stderr)
	return $text

Function _liveEnvelope($form : Object; $result : Object)
	This.lastResult:=$result
	This.envelopeText:=This.envelope($result)
	If (Not($result.ok))
		This.statusText:="live call refused · "+This.code($result)
	End if

// FN from a vCard Text without calling the CLI (listbox display).
Function cardName($vcard : Text)->$name : Text
	var $lines : Collection
	var $line : Text
	$name:=""
	$lines:=This.cardText.lines($vcard)
	For each ($line; $lines)
		If (Substring($line; 1; 3)="FN:")
			$name:=Substring($line; 4)
			return $name
		End if
	End for each
	return $name

Function cardVersion($vcard : Text)->$version : Text
	var $lines : Collection
	var $line : Text
	$version:=""
	$lines:=This.cardText.lines($vcard)
	For each ($line; $lines)
		If (Substring($line; 1; 8)="VERSION:")
			$version:=Substring($line; 9)
			return $version
		End if
	End for each
	return $version

Function _join($values : Variant)->$text : Text
	var $value : Variant
	$text:=""
	If (Value type($values)#Is collection)
		return $text
	End if
	For each ($value; $values)
		If (Value type($value)=Is text)
			If (Length($text)>0)
				$text:=$text+", "
			End if
			$text:=$text+String($value)
		End if
	End for each
	return $text

Function _boolText($flag : Variant)->$text : Text
	$text:="no"
	If (Value type($flag)=Is Boolean)
		If (String($flag)="true")
			$text:="yes"
		End if
	End if
	return $text

Function _text($value : Variant)->$text : Text
	$text:=""
	If (Value type($value)=Is text)
		$text:=String($value)
	End if
	return $text

Function _int($value : Variant)->$number : Integer
	$number:=0
	If ((Value type($value)=Is longint) | (Value type($value)=Is real))
		$number:=Int($value)
	End if
	return $number
