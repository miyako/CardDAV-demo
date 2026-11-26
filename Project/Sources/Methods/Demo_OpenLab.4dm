// Opens the vCard Lab window. Called by the Demo menu and by the Studio.
// Start-method pattern: without a parameter it reuses an open window or hands
// over to worker 1; with a parameter it opens the window there (non-blocking).
#DECLARE($params : Object)

var $title : Text
var $window; $i; $left; $top; $right; $bottom : Integer

$title:="CardDAV — vCard Lab"

If (Count parameters=0)
	
	// already open? bring it to the front instead of opening a duplicate
	ARRAY LONGINT($windows; 0)
	WINDOW LIST($windows)
	For ($i; 1; Size of array($windows))
		$window:=$windows{$i}
		If (Window process($window)=1) && (Get window title($window)=$title)
			GET WINDOW RECT($left; $top; $right; $bottom; $window)
			CALL FORM($window; Formula(SET WINDOW RECT($left; $top; $right; $bottom; $window)))
			return 
		End if 
	End for 
	
	CALL WORKER(1; Current method name; {})
	
Else 
	
	SET MENU BAR(1)
	$window:=Open form window("Lab"; Plain form window; Horizontally centered; Vertically centered)
	SET WINDOW TITLE($title; $window)
	DIALOG("Lab"; $params; *)
	
End if 
