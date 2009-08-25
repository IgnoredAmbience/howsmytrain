<html>
<head>
	<link rel="stylesheet" type="text/css" href="style.css"/>
</head>
<body style="width: 100%; margin:0 auto;">
<div id="contentMain">
	<img src="trainlogo.png"/>
	<form name="service" action="stage2services.php" method="get">
	<p>
		Station:
		<select name="station">
			<?php
                require('include.php');
                init_db();
				$result = mysql_query("SELECT * FROM stations");
				$rows = mysql_numrows($result);
				mysql_close();
				$i = 0;
				while($i < $rows)
				{
					print "<option value='";
					print mysql_result($result,$i,"crs");
					print "'>";
					print mysql_result($result,$i,"name"); 
					print "</option>"; 
					$i++;
				}
			?>
		</select>
	</p>
	<p>
		Day:
		<select name="day">
			<option value="1">Monday</option>
			<option value="2">Tuesday</option>
			<option value="3">Wednesday</option>
			<option value="4">Thursday</option>
			<option value="5">Friday</option>
			<option value="6">Saturday</option>
			<option value="7">Saturday</option>
		</select>
	</p>
	<p>
		Time:
		<select name="timehours">
			<option value="00">00</option>
			<option value="01">01</option>
			<option value="02">02</option>
			<option value="03">03</option>
			<option value="04">04</option>
			<option value="05">05</option>
			<option value="06">06</option>
			<option value="07">07</option>
			<option value="08">08</option>
			<option value="09">09</option>
			<option value="10">10</option>
			<option value="11">11</option>
			<option value="12">12</option>
			<option value="13">13</option>
			<option value="14">14</option>
			<option value="15">15</option>
			<option value="16">16</option>
			<option value="17">17</option>
			<option value="18">18</option>
			<option value="19">19</option>
			<option value="20">20</option>
			<option value="21">21</option>
			<option value="22">22</option>
			<option value="23">23</option>
			<option value="24">24</option>
		</select>
		<select name="timeminutes">
			<option value="00">00</option>
			<option value="15">15</option>
			<option value="30">30</option>
			<option value="45">45</option>
		</select>
	</p>
	<p><br/>
		<input type="submit" value="Next"/>
	</p>
	</form>
</div>
</body>
</html>
