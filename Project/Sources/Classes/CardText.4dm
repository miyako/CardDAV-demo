// CardText -- byte-level inspection of vCard Text.
//
// The component's contract is "the raw parser preserves the supplied vCard
// Text": CRLF framing, 75-octet folding and unknown properties survive parse()
// and are what update() sends back. These functions exist so the demo can show
// that contract instead of asserting it, and so the headless report can audit
// real builder output.
//
// Pure functions only: no form state, no component calls, no disk access.

Class constructor()
	// Stateless helper.

// UTF-8 octets of a Text value. Length() counts characters; folding limits are
// expressed in octets, so the two are not interchangeable for Japanese or
// accented names.
Function octets($text : Variant)->$octets : Integer
	var $blob : Blob
	$octets:=0
	If (Value type($text)#Is text)
		return $octets
	End if
	TEXT TO BLOB(String($text); $blob; UTF8 text format)
	$octets:=BLOB size($blob)

// Exact equality. 4D's = on Text ignores case and diacritics, so it would call
// "FN:Miyako" and "FN:miyako" the same. The lossless claim is about bytes:
// compare the length and the SHA-256 of the UTF-8 octets instead.
Function sameText($a : Variant; $b : Variant)->$same : Boolean
	$same:=False
	If ((Value type($a)#Is text) | (Value type($b)#Is text))
		return $same
	End if
	If (This.octets($a)#This.octets($b))
		return $same
	End if
	$same:=(Generate digest(String($a); SHA256 digest)=Generate digest(String($b); SHA256 digest))

// Physical lines, split on CRLF or bare CR/LF. A trailing terminator does not
// create an empty last line.
Function lines($text : Variant)->$lines : Collection
	var $flat : Text
	var $pos; $next : Integer
	$lines:=New collection
	If (Value type($text)#Is text)
		return $lines
	End if
	$flat:=Replace string(String($text); Char(13)+Char(10); Char(10); *)
	$flat:=Replace string($flat; Char(13); Char(10); *)
	$pos:=1
	Repeat
		$next:=Position(Char(10); $flat; $pos; *)
		If ($next=0)
			$lines.push(Substring($flat; $pos))
			$pos:=-1
		Else
			$lines.push(Substring($flat; $pos; $next-$pos))
			$pos:=$next+1
		End if
	Until ($pos<0)
	If (($lines.length>0) & ($lines[$lines.length-1]=""))
		$lines.pop()
	End if

Function crlfCount($text : Variant)->$count : Integer
	var $i; $n : Integer
	$count:=0
	If (Value type($text)#Is text)
		return $count
	End if
	$n:=Length($text)
	For ($i; 1; $n-1)
		If ((Character code(Substring($text; $i; 1))=13) & (Character code(Substring($text; $i+1; 1))=10))
			$count:=$count+1
		End if
	End for

Function bareLfCount($text : Variant)->$count : Integer
	var $i; $n; $code : Integer
	$count:=0
	If (Value type($text)#Is text)
		return $count
	End if
	$n:=Length($text)
	For ($i; 1; $n)
		$code:=Character code(Substring($text; $i; 1))
		If ($code=10)
			If (($i=1) | (Character code(Substring($text; $i-1; 1))#13))
				$count:=$count+1
			End if
		End if
	End for

// One audit object for the console and the headless report.
Function audit($text : Variant)->$audit : Object
	var $lines : Collection
	var $line : Text
	var $i; $n; $max; $over; $folded; $lead : Integer
	$audit:=New object("lineCount"; 0; "longestLineOctets"; 0; "linesOver75"; 0; "foldedLines"; 0; "crlfCount"; 0; "bareLfCount"; 0; "hasBom"; False)
	If (Value type($text)#Is text)
		return $audit
	End if
	$lines:=This.lines($text)
	For each ($line; $lines)
		$n:=This.octets($line)
		If ($n>$max)
			$max:=$n
		End if
		If ($n>75)
			$over:=$over+1
		End if
		If (Length($line)>0)
			$lead:=Character code(Substring($line; 1; 1))
			If (($lead=32) | ($lead=9))
				$folded:=$folded+1
			End if
		End if
	End for each
	$audit.lineCount:=$lines.length
	$audit.longestLineOctets:=$max
	$audit.linesOver75:=$over
	$audit.foldedLines:=$folded
	$audit.crlfCount:=This.crlfCount($text)
	$audit.bareLfCount:=This.bareLfCount($text)
	$audit.hasBom:=(Length($text)>0) & (Character code(Substring($text; 1; 1))=65279)

// CR and TAB made visible for the console; the line feed stays a real break so
// a reader can count physical lines.
Function visible($text : Variant)->$display : Text
	$display:=""
	If (Value type($text)#Is text)
		return $display
	End if
	$display:=Replace string(String($text); Char(13); "␍"; *)
	$display:=Replace string($display; Char(9); "⇥"; *)
	$display:=Replace string($display; Char(0); "␀"; *)

// The set of property names in a parse() properties collection.
Function nameSet($properties : Variant)->$set : Object
	var $property : Object
	$set:=New object
	If (Value type($properties)#Is collection)
		return $set
	End if
	For each ($property; $properties)
		If (Value type($property)=Is object)
			If (Value type($property.name)=Is text)
				$set[$property.name]:=True
			End if
		End if
	End for each

// Properties present before a rebuild but absent after it. A rebuild from the
// parsed summary cannot keep PHOTO, X-* or group prefixes; naming them is the
// point of the lossless-vs-rebuild demonstration.
Function lostProperties($before : Variant; $after : Variant)->$lost : Collection
	var $property : Object
	var $kept : Object
	var $value : Text
	$lost:=New collection
	If ((Value type($before)#Is collection) | (Value type($after)#Is collection))
		return $lost
	End if
	$kept:=This.nameSet($after)
	For each ($property; $before)
		If (Value type($property)=Is object)
			If (Value type($property.name)=Is text)
				If (Value type($kept[$property.name])=Is undefined)
					$value:=""
					If (Value type($property.value)=Is text)
						$value:=$property.value
					End if
					If (Length($value)>40)
						$value:=Substring($value; 1; 40)+"…"
					End if
					$lost.push(New object("name"; $property.name; "value"; $value))
				End if
			End if
		End if
	End for each

// A compact audit line for a form label.
Function auditText($audit : Object)->$text : Text
	$text:="lines "+String($audit.lineCount)+" · longest "+String($audit.longestLineOctets)+" octets"
	If ($audit.linesOver75>0)
		$text:=$text+" · "+String($audit.linesOver75)+" over 75"
	Else
		$text:=$text+" · folding within 75"
	End if
	If ($audit.bareLfCount>0)
		$text:=$text+" · "+String($audit.bareLfCount)+" bare LF"
	Else
		$text:=$text+" · all CRLF"
	End if
	return $text
