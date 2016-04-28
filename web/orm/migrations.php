<?php

require_once('db_conf.php');

require_once('models/DBmodels.php');

$mapper = $spot->mapper('Entity\NetworkDB');
$mapper->migrate();

echo "Done";

?>
