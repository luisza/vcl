<?php

/* 
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */
require_once 'views/ViewsManager.php';
require 'db_conf.php';

function registerApps(&$actions){
    global $views;
    foreach($views as $key => $view){
        $actions['mode'][$key] = 'ormController';
        $actions['pages'][$key] = 'ormController';
        array_push($actions["entry"] , $key); 
    }
}

function getMenu(){
    $dev = [];
    global $views;
    foreach($views as $key => $view){
        if($view['menu']){
            $dev [ $key] = $view['verbose_name'];
        }
    }
    return $dev;
}

function ormController(){
    global $mode, $manager;
    $manager->processView($mode);

}
