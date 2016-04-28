<?php

require_once ('BaseModel.php');

class Network extends BaseModel {
    public $model = 'Entity\NetworkDB';
    
    public $labels = [
        'name'  =>  "Name",
        'cidr'  => "Classless Inter-Domain Routing",
        'gateway' => "Gateway",
        'networkmask' => "Network Mask"
    ];
}
    


?>
