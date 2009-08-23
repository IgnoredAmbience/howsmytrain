<?php
mysql_connect("192.168.144.45","root","");
@mysql_select_db("howsmytrain") or die("unable to connect to database");

$sid = mysql_real_escape_string($_GET['i']);
$crs = mysql_real_escape_string($_GET['s']);

$sql = "SELECT Day,Arrival,Scheduled FROM performance WHERE ServiceID = '$sid' AND Station = '$crs' ORDER BY Day DESC";
$result = mysql_query($sql);
while($iter = mysql_fetch_assoc($result)) {
	$arr = strtotime($iter['Arrival']);
	$sch = strtotime($iter['Scheduled']);
	$late = ($arr - $sch) / 60;
	echo $iter['Day'], ',', $late;
}

?>

