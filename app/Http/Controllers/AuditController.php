<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Http\Response;
use App\Http\Traits\AuditsTrait;

class AuditController extends Controller
{
    use AuditsTrait;
    public $response;

    /**
     * Create a new controller instance.
     *
     * @return void
     */
    public function __construct()
    {
        $this->response = new Response();
    }

    /**
     * Get the last content, today, of logs
     *
     * @param Request $request - data sent by http request
     * @return array JSON
     */
    public function today(Request $request)
    {
        if($request->bearerToken() !== config('app.masterToken')) {  // token is not valid
            $this->createLog('Exception #401 [Unauthorized. Token provided is not valid.]', 'errors'); //set error
            return $this->response->setStatusCode('401', 'Unauthorized. Token provided is not valid.');
        } else { // token is valid
            return $this->getTodayLog($request->type);
        }
    }
}
