<?php

require_once ('DBmodels.php');

class BaseModel {

	public $mapper = null;
	public $instance = null; 
        public $labels = [];
        public $model = '';
        
	function __construct() {
            global $spot;
            $this->mapper =  $spot->mapper($this->model);
	}

        
        public function fields(){
    
            return $this->mapper->fields();
        }
        
        public function label($key){
            if(array_key_exists ($key,  $this->labels)){
                return $this->labels[$key];
            }
            return $key;
        }
        
	public function build($data){
		$this->instance =  $this->mapper->build($data);
	}

	public function create($data){
		$this->instance =  $this->mapper->create($data);
	}

	public function insert($data){
		$result = $mapper->insert($data);
		// Fetch inserted record by ID
		if ($result) {
			$this->instance = $this->mapper->get($result);
		}
		return $result;
	}
	public function save($data){
		$result = $this->mapper->save($this->instance);		
		return $result;
	}
	public function update(){
		$this->mapper->update($this->instance);
	}
}
