<?php
$svcid = htmlspecialchars($_GET['ServiceID']);
$stid = htmlspecialchars($_GET['station']);
$query = "?i=$svcid&s=$stid";
?>

<html>
<head>
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
	<link rel="stylesheet" type="text/css" href="style.css"/>
<title>How's My Train -- Performance Information</title>
</head>
<body>
  <script type="text/javascript" src="amline/swfobject.js"></script>
	<div id="contentGraph">
	<div id="flashcontent" style="text-align: center">
		<strong>You need to upgrade your Flash Player</strong>
	</div>

<?php
require('include.php');
init_db();

// HACK HACK HACK
$svcid = 'NMP-LIV-06:06-08:35-1';
$stid  = 'RUG';

$sid = mysql_real_escape_string($svcid);
$crs = mysql_real_escape_string($stid);

$sql = "SELECT Day,Arrival,Scheduled FROM performance WHERE ServiceID = '$sid' AND Station = '$crs' ORDER BY Day ASC";
$result = mysql_query($sql);

$i    = 0;
$ppm  = 0;
$data = '';

while($iter = mysql_fetch_assoc($result)) {
	$arr = strtotime($iter['Arrival']);
	$sch = strtotime($iter['Scheduled']);
	$late = ($arr - $sch) / 60;
	if($late < 0)
		$late = 0;

	if($late == 1 || $late == -1)
		$min = 'minute';
	else
		$min = 'minutes';

	if($late == 0)
		$desc = "On time";
	else if($late < 0)
		$desc = "Early (" . -$late . " $min)";
	else
		$desc = "Late ($late $min)";

	$series .= "<value xid='" . $i . "'>" . $iter['Day'] . "</value>";
	$graph  .= "<value xid='" . $i . "' description='" . $desc . ' ' . "'>" . $late . "</value>";

	if($late >= 10)
		$ppm++;

	$i++;
}

if (!$i) die("No data available")

$onTime = (int) ((($i - $ppm) * 100) / ($i));
$dest   = substr($_GET['ServiceID'], 4, 3);
$time   = substr($_GET['ServiceID'], 14, 5);

$xml = '<chart><series>';
$xml .= $series;
$xml .= "</series><graphs><graph gid='1'>";
$xml .= $graph;
$xml .= '</graph></graphs>';
$xml .= "<labels>";
$xml .= "<label lid='0'><x></x><y>20</y><width>1000</width><align>center</align><text>";
$xml .= "<![CDATA[<b>Train Performance Information for $dest $time arrival</b>]]>";
$xml .= '</text></label>';
$xml .= "<label lid='1'><x></x><y>50</y><width>1000</width><align>center</align><text>";
$xml .= "<![CDATA[<b>On time:</b> <u>$onTime%</u>]]>";
$xml .= '</text></label>';
$xml .= '</labels></chart>';
$data = $xml;

?>
	<script type="text/javascript">
		// <![CDATA[		
		var so = new SWFObject("amline/amline.swf", "amline", "1000", "600", "8", "#FFFFFF");
		so.addVariable("path", "amline/");
		so.addVariable("settings_file", encodeURIComponent("amline/amline_settings.xml"));                // you can set two or more different settings files here (separated by commas)
		so.addVariable("chart_data", escape("<?=$data?>"));                    // you can pass chart data as a string directly from this file
		so.write("flashcontent");
		// ]]>
	</script>
	<a href="<?php print $_SERVER['HTTP_REFERER']?>">Back</a>

	</div>
<!-- end of amline script -->


</body>
</html>
