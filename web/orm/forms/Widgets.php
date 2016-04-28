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

    function __construct($name, $label, $required){
        $this->name = $name;
        $this->required = $required;
        $this->label = $label;
    }

    public function  inicialize($value){
        $this->value = $value;
    }
    
    public function  validate(){}
    public function render(){}
    public function label(){
       return sprintf('<label for="%s" >%s</label>', $this->name, $this->label);
    }
    
    
}

class TextField extends Field{
    public $type = "text";
    public $extras = "";
    
    public function render(){
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