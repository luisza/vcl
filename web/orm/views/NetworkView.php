<?php


require_once 'BaseViews.php';
require_once __DIR__.'/../models/network.php';

class CreateNetworkView extends BaseEditView{
    public $model = 'Network';
    public $template_name= 'network.html';
    public $name = 'CreateNetwork';
    public $verbose_name = 'Manage networks create';
    private $redirect_success = 'ListNetwork';
    
    public function get(){
        $form = $this->getForm();
        $twig = $this->getTemplateLoader();
        echo $twig->render($this->template_name, array('form' => $form ));
    }
    
    public function post(){
        $form = $this->getForm();
        $form->fillForm('POST');
        if($form->isValid()){
            $this->save($form);
            $form = $this->getForm();
            # FIXME: Works with headers out of vcl
            #header('Location: ?mode='.$this->redirect_success);
            echo "<script> location.replace('?mode=".$this->redirect_success."'); </script>";
            die();
            
        }
        $twig = $this->getTemplateLoader();
        echo $twig->render($this->template_name, array('form' => $form ));       
    }
}

class EditNetworkView extends CreateNetworkView{
    public $model = 'Network';
    public $template_name= 'network.html';
    public $name = 'EditNetwork';
    public $verbose_name = 'Manage networks editview';    
    private $redirect_success = 'ListNetwork';
    
    public function get(){
        if(isset($_GET['pk']) ){
            $instance = new $this->model;
            $instance->load($_GET['pk']);
            $this->instance = $instance;
            // TODO: Raise exception if $instance is null
        }
        parent::get();
    }
    
    private function _get_pk($instance){
        $pks = $instance->getPkField();
        $values = array();
        foreach ($pks as $pk){
            if (isset($_POST[$pk])) {
                $values[$pk] = $_POST[$pk];
            }
        }
        return $values;
    }
    public function post(){
        $instance = new $this->model;        
        $fields = $this->_get_pk($instance);
        if(count($fields)>0 ){
            $instance->load( $fields );
            $this->instance = $instance;
            // TODO: Raise exception if $instance is null
        }
        parent::post();
    }      
}

// FIXME: Abstract view for list fields
class ListNetworkView extends BaseEditView {
    public $model = 'Network';
    public $template_name= 'network_list.html';
    public $name = 'ListNetwork';
    public $verbose_name = 'Manage networks';    

    public function get(){
        $net = new $this->model;
        $nets = $net->mapper->all();
        $twig = $this->getTemplateLoader();
        echo $twig->render($this->template_name, array('object_list' => $nets ));
    }
}

class DeleteNetworkView extends BaseEditView{
    public $model = 'Network';
    public $template_name= 'network_delete.html';
    public $name = 'DeleteNetwork';
    public $verbose_name = 'Manage networks delete';    
    private $redirect_success = 'ListNetwork';
    
    public function save(){}

    public function get(){
        if(isset($_GET['pk']) ){
            $instance = new $this->model;
            $instance->load($_GET['pk']);
            $this->instance = $instance;
            // TODO: Raise exception if $instance is null
        }
        $twig = $this->getTemplateLoader();
        echo $twig->render($this->template_name, array(
            'instance' => $this->instance->instance ));
    }
    
    public function post(){
        if(isset($_POST['pk']) ){
            $instance = new $this->model;
            $instance->load($_POST['pk']);
            // TODO: Raise exception if $instance is null
            $instance->delete();
        }
        # FIXME: Works with headers out of vcl
        #header('Location: ?mode='.$this->redirect_success);
        echo "<script> location.replace('?mode=".$this->redirect_success."'); </script>";
        die();  
    } 
    
}

