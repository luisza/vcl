<?php

/* 
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */

class Field{
    // Base field functions and attrs
    public $name;
    public $value = null;
    public $required = False;
    public $label = "";
    public $error_message = "";
    private $stated = False;
    private $edited = False;

    function __construct($name, $label, $required){
        $this->name = $name;
        $this->required = $required;
        $this->label = $label;
    }

    public function  inicialize($value){
        $this->value = $value;
        $this->started = True;
    }
    
    public function  validate(){}
    public function render(){}
    public function label(){
        $require="";
        if($this->required){
           $require="(*)"; 
        }
       return sprintf('<label for="%s" >%s %s</label>', 
               $this->name, 
               $this->label, 
               $require);
    }
    
    public function setValue($value){
        if($this->started){
            if($value != $this->value ){
                $this->value = $value;
                $this->edited=True;
            }
        }else{
            $this->value = $value;
        }
    }
    
    function wasEdited() {
        return $this->edited;
    }


    
}

class TextField extends Field{
    public $type = "text";
    public $extras = "";
    
    public function render(){
        if($this->error_message != ""){
            
        }
        $tmp_val = "";
        if( $this->value != null){
            $tmp_val = $this->value;
        }
        $require="";
        if($this->required){
           $require="required"; 
        }
        return sprintf('<input type="%s" id="id_%s" name="%s" value="%s" %s %s>',
                        $this->type, $this->name, $this->name,
                        $this->value, $this->extras, $require);
    }
    
}

class Number extends TextField{
    public $type = "number";   
}

class Hidden extends TextField{
    public $type = "hidden";   
    public function label(){
        return "";
    }
}


class WidgetFactory{
    
    public static function getWidget($name){

        switch ($name){
            case 'string':
                return 'TextField';
            case 'integer':
                return 'Number';
            case 'hidden':
                return 'Hidden';
        }
       return Field;
    }
}