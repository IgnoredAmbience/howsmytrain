<html>
<head>
	<link rel="stylesheet" type="text/css" href="style.css"/>
</head>
<body>
<div id="contentMain">
	<a href="/howsmytrain/"><img src="trainlogo.png"/></a>
		<?php
			
			//Connect to the database and get table data
			mysql_connect("192.168.144.45","root","");
			@mysql_select_db("howsmytrain") or die("unable to connect to database");
			$sql = 'SELECT * FROM timetables WHERE StopsAt="' . $_GET['station'] . '" AND Day = ' . $_GET['day'] . ' AND StopsWhen >="' . $_GET['timehours'] . ':' . $_GET['timeminutes'] . ':00"' . ' ORDER by StopsWhen limit 5';
			$result = mysql_query($sql);
			$rows = mysql_numrows($result);
			while($iter = mysql_fetch_assoc($result))
			{
				//print route sentence
				print "<h3><a href='displaygraph.php?";
				print 'ServiceID=' . $iter['ServiceID'] . '&station=' . $_GET['station'];
				print "'>";
				$sql = 'SELECT * FROM stations WHERE crs ="' . $iter['ServiceID'][0] . $iter['ServiceID'][1] . $iter['ServiceID'][2] . '" limit 1';
				$stationnameresult = mysql_query($sql);
				print mysql_result($stationnameresult,0,'name');
				print ' to ';
				$sql = 'SELECT * FROM stations WHERE crs = "' . $iter['ServiceID'][4] . $iter['ServiceID'][5] . $iter['ServiceID'][6] . '" limit 1';
				$deststationnameresult = mysql_query($sql);
				print mysql_result($deststationnameresult,0,'name');
				print '</a></h3>';				

				//Get sub entries
				$sql = 'SELECT stopsWhen FROM timetables WHERE ServiceID = "' . $iter['ServiceID'] . '" AND StopsAt = "' . $_GET['station'] . '"';
				$subresult = mysql_query($sql);
				while($subiter = mysql_fetch_assoc($subresult))
				$arrival = $subiter['stopsWhen'];
				$sql = 'SELECT stopsAt, stopsWhen FROM timetables WHERE ServiceID = "' . $iter['ServiceID'] . '" AND StopsWhen > "' . $arrival . '"';
				$subresult = mysql_query($sql);
				print '<ul class="journey">';
				while($subiter = mysql_fetch_assoc($subresult))
				{	

					$sql = 'SELECT * FROM stations WHERE crs = "' . $subiter['stopsAt'] . '" limit 1';
					$substationname = mysql_query($sql);			
					print '<li><span>&nbsp;</span>Calls at ' . mysql_result($substationname,0,'name') . ' at ' . $subiter['stopsWhen']; 
				}
				$sql = 'SELECT * FROM stations WHERE crs = "' . $iter['ServiceID'][4] . $iter['ServiceID'][5] . $iter['ServiceID'][6] . '" limit 1';
				$originalstationname = mysql_query($sql);
				print '<li> Calls at ' . mysql_result($originalstationname,0,'name') . ' at ' . $iter['ServiceID'][14] . $iter['ServiceID'][15] . $iter['ServiceID'][16] . $iter['ServiceID'][17] . $iter['ServiceID'][18] . ':00'; 
				print '</ul>';
				}

				if(!$rows)
				{
					print '<br/></br>No matches found';
				}
			
		?><br/>
</div>
</body>
</html>
