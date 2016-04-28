<?php

/* 
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */

require_once 'Widgets.php';

class Form{
    private $widgets = array();
    
    public function addWidget($widget){
        array_push($this->widgets, $widget);
    }
    
    public function render(){
        foreach ($this->widgets as $widget){
            print $widget->render();
        }
    }
    
    public function renderAsTable(){
        $print = "";
       foreach ($this->widgets as $widget){
            $print .= "<tr><td>".$widget->label()."</td>";
            $print .= "<td>".$widget->render()."</td></tr>";
        }  
        return $print;
    }
    
}

class ModelFormBuilder{
    private $form = null;

    function __construct() {
        $this->form = new Form();
    }
    
    private function fillFields($widget,$obj, $instance, $field, $values){
        if(in_array('default', $values)){
         $widget->inicialize($values['default']);
        }       
        if($instance != NULL){
            $widget->inicialize($instance->$field);
        }
    }

    
    public function loadModel($obj, $instance=NULL){
        if(is_a($obj, 'BaseModel')){
            $fields = $obj->fields();
            foreach ($fields as $field  => $value){
                $fieldtype = $value['type'];
                
                if(in_array('primary', $value) && $value['primary']){
                   $fieldtype='hidden';
                }
                $fieldClass = WidgetFactory::getWidget($fieldtype);
                $required=False;
                
                if(in_array('required', $value)){
                    $required = $fields[$field]['required'];
                }
                $label = $obj->label($field);
                $widget = new $fieldClass($field, $label, $required);
               $this->fillFields($widget,$obj, $instance, $field, $value);                
                $this->form->addWidget($widget);
            }
        }
        return $this->form;
    }
}