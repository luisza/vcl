<?php 

require 'vendor/autoload.php';

$cfg = new \Spot\Config();
$cfg->addConnection('mysql', 'mysql://vlcorm:vlcorm@localhost/vlcorm');
$spot = new \Spot\Locator($cfg);
