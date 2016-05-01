<?php

/* 
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */

include 'NetworkView.php';
        
class ViewsFactory{
    private $views = [];
    private static $instance;
    
    
    public static function getInstance() {
        if (null === static::$instance) {
            static::$instance = new static();
        }
        
        return static::$instance;
    }
    protected function __construct()  { }
    private function __clone() { }
    private function __wakeup() { }
    
    
    public function register($view, $inmenu=True){
        $view = new $view;
        $this->views[$view->getName()] =  [
            'verbose_name' => $view->getVerbose_name(),
            'view' => $view,
            'menu' => $inmenu];
                
                
    }
    public function getView($name){
        if(array_key_exists($name, $this->views)){
            return $this->views[$name]['view'];
        }
    }
    function getViews() {
        return $this->views;
    }

    public function processView($name){
        $viewclass = $this->getView($name);
        $view = new $viewclass;
        if($_SERVER['REQUEST_METHOD'] === 'GET'){
            print $view->get();
        }else if ($_SERVER['REQUEST_METHOD'] === 'POST'){
            print $view->post();
        }
    }
        
    public function loads(){
        
        if(count($this->views) == 0){
            $this->register('CreateNetworkView', False);
            $this->register('EditNetworkView');
            $this->register('ListNetworkView');
        }else{
             return;
        }
    }
    
}

$manager = ViewsFactory::getInstance();
$manager->loads();

$views = $manager->getViews();
