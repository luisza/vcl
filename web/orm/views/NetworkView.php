<?php


require_once 'BaseViews.php';
require_once __DIR__.'/../models/network.php';

class CreateNetworkView extends CreateView{
    public $model = 'Network';
    public $template_name= 'network.html';
    public $name = 'CreateNetwork';
    public $verbose_name = 'Manage networks create';
    public $redirect_success = 'ListNetwork';

}

class EditNetworkView extends EditView{
    public $model = 'Network';
    public $template_name= 'network.html';
    public $name = 'EditNetwork';
    public $verbose_name = 'Manage networks editview';    
    public $redirect_success = 'ListNetwork';
}

class ListNetworkView extends ListView  {
    public $model = 'Network';
    public $template_name= 'network_list.html';
    public $name = 'ListNetwork';
    public $verbose_name = 'Manage networks';    
}

class DeleteNetworkView extends DeleteView{
    public $model = 'Network';
    public $template_name= 'network_delete.html';
    public $name = 'DeleteNetwork';
    public $verbose_name = 'Manage networks delete';    
    public $redirect_success = 'ListNetwork';
    
}