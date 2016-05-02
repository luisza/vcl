<?php

require_once( __DIR__.'/../forms/FormBuilder.php');

class BaseEditView{
    public $instance = NULL;
    public $model =NULL;
    public $template_name = NULL;
    public $name = NULL;
    public $verbose_name = NULL;   
    
    function __construct($instance=NULL) {
        $this->instance = $instance;
    }

    protected function getTemplateLoader(){
        $loader = new Twig_Loader_Filesystem(getcwd().'/orm/templates');
        $twig = new Twig_Environment($loader);
        return $twig;
    }
    
    public function getForm($includeFields=NULL){
        $formBuilder= new ModelFormBuilder();
        $form = $formBuilder->loadModel(new $this->model(), 
                                        $instance=$this->instance,
                                        $includefields=$includeFields
                                );
        return $form;
    }
    public function get(){}
    public function post(){}
    
    public function save($form){
        $values = [];
        $widgets = $form->getWidgets($onlyEdit=$this->instance != NULL);
        foreach ($widgets as $widget){
             $values[$widget->name] = $widget->value;
        }
        if($this->instance != NULL){
            $this->instance->update($values);
        } else {
            $instance = new $this->model;
            $instance->mapper->insert($values);
        }
    }
    function getName() {
        return $this->name;
    }

    function getVerbose_name() {
        return $this->verbose_name;
    } 
}


class CreateView extends BaseEditView{
    public $model = Null;
    public $template_name= 'change_form.html';
    public $name = Null;
    public $verbose_name = 'Update verbose_name';
    public $redirect_success = 'main';
    
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


class EditView extends CreateView{
    
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
        //FIXME: Find a better solution like $mapper->primaryKeyField() 
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
class ListView extends BaseEditView {
    public $list_filter = NULL;
    
    private function getFormFilter(){
        if($this->list_filter==NULL) return NULL;
        $form = $this->getForm($this->list_filter);
        $form->fillForm("GET");
        return $form;
    }
    public function get(){
        $net = new $this->model;
        //FIXME: provide filters 
        $form = $this->getFormFilter();
        //print_r($form);
        if($form == NULL){
            $nets = $net->mapper->all();
        }else{
            $nets = $net->mapper->where($form->getData());
        }
        $twig = $this->getTemplateLoader();
        echo $twig->render($this->template_name, array(
                                'object_list' => $nets,
                                'form' => $form
                             ));
    }
    
    public function post(){}
}

class DeleteView extends BaseEditView{   
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
