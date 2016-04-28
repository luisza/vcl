<?php

namespace Entity;

require __DIR__.'/../db_conf.php';

class NetworkDB extends \Spot\Entity {

    protected static $table = 'networks';
    public static function fields()
    {
        return [
            'id'           	=> ['type' => 'integer', 'primary' => true, 'autoincrement' => true],
            'name'         	=> ['type' => 'string', 'required' => true],
            'cidr'         	=> ['type' => 'string', 'required' => true],
            'gateway'       => ['type' => 'string', 'required' => true],
            'networkmask'   => ['type' => 'string', 'required' => true],
            'mut' 			=> ['type' => 'integer',  'default'=> 360, 'required' => true]
        ];
    }
} 