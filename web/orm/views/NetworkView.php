<?php


require_once 'BaseViews.php';
require_once __DIR__.'/../models/network.php';

class CreateNetworkView extends BaseEditView{
    public $model = Network;
    public $template_name= 'network.html';
    public static $name = 'CreateNetwork';
    public static $verbose_name = 'Manage networks';
    
    public function get(){
        $form = $this->getForm();
        $twig = $this->getTemplateLoader();
        echo $twig->render($this->template_name, array('form' => $form ));
    }
    static function getName() {
        return self::$name;
    }

    static function getVerbose_name() {
        return self::$verbose_name;
    }
}

// FIXME: Abstract view for list fields
class ListNetworkView extends BaseEditView {
    public $model = Network;
    public $template_name= 'network_list.html';
    public static $name = 'ListNetwork';
    public static $verbose_name = 'List networks';    

    public function get(){
        $net = new $this->model();
        $nets = $net->mapper->all();
        $twig = $this->getTemplateLoader();
        echo $twig->render($this->template_name, array('object_list' => $nets ));
    }
    static function getName() {
        return self::$name;
    }

    static function getVerbose_name() {
        return self::$verbose_name;
    }


    
}