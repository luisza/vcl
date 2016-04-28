<?php

require 'db_conf.php';

require_once( './models/network.php');
require_once( './forms/FormBuilder.php');

$net = new Network();


$instance = $net->mapper->get(20);


$formBuilder= new ModelFormBuilder();
$form = $formBuilder->loadModel($net, $instance);


$loader = new Twig_Loader_Filesystem(getcwd().'/templates');
$twig = new Twig_Environment($loader);


echo $twig->render('network.html', array('form' => $form ));

echo "done";

