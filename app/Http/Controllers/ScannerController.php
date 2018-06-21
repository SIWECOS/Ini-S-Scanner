<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Http\Response;
use App\Http\Traits\AuditsTrait;

class ScannerController extends Controller
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
    public function testare(Request $request)
    {
        return $this->createLog('blabla');
    }



}
