<?php
function init_db() {
    mysql_connect("localhost","howsmytrain","");
    @mysql_select_db("howsmytrain") or die("unable to connect to database");
}
?>