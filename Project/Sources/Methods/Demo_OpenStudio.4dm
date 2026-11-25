// Opens the CardDAV Studio window. Called by On Startup and by the Demo menu.
// The form runs in this process; the menu can open the Lab on top of it.
#DECLARE($params : Object)

var $title : Text
var $window : Integer

$title:="CardDAV — Studio"
SET MENU BAR(1)
$window:=Open form window("Studio"; Plain form window; Horizontally centered; Vertically centered)
SET WINDOW TITLE($title; $window)
If (Count parameters=0)
	DIALOG("Studio"; New object; *)
Else
	DIALOG("Studio"; $params; *)
End if
