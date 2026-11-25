// Opens the vCard Lab window in this process, like the Studio.
#DECLARE($params : Object)

var $title : Text
var $window : Integer

$title:="CardDAV — vCard Lab"
SET MENU BAR(1)
$window:=Open form window("Lab"; Plain form window; Horizontally centered; Vertically centered)
SET WINDOW TITLE($title; $window)
If (Count parameters=0)
	DIALOG("Lab"; New object; *)
Else
	DIALOG("Lab"; $params; *)
End if
