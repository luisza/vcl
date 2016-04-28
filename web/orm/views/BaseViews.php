<?php

require_once( __DIR__.'/../forms/FormBuilder.php');

class BaseEditView{
    public $instance = NULL;
    public $model =NULL;
    public $template_name = NULL;
    
    function __construct($instance=NULL) {
        $this->instance = $instance;
    }

    protected function getTemplateLoader(){
        $loader = new Twig_Loader_Filesystem(getcwd().'/orm/templates');
        $twig = new Twig_Environment($loader);
        return $twig;
    }
    
    public function getForm(){
        $formBuilder= new ModelFormBuilder();
        $form = $formBuilder->loadModel(new $this->model(), $this->instance);
        return $form;
    }
    public function get(){}
    public function post(){}
}