<?php

namespace App\Http\Controllers;

use Storage;
use Exception;
use Illuminate\Http\Request;
use Illuminate\Http\Response;
use Carbon\Carbon;

class AuditController extends Controller
{
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
    public function new(Request $request)
    {
        // check if the token is valid
        if($request->bearerToken() !== config('app.masterToken')) {
            return $this->response->setStatusCode('401', 'Unauthorized. Token provided is not valid.');
        } else {

            try {

//                throw new Exception('testare exceptie');

                $exists = Storage::disk('audits')->has('test.txt');
                $contents = Storage::disk('audits')->get('test.txt');

                Storage::disk('audits')->append('test.txt', 'Appended Text');

                return response()->json(['message' => 'Test', 'exist' => $exists, 'content' => $contents, 'request' => $request->bearerToken()], 200);

            } catch(Exception $exception) {
                return $this->response->setStatusCode('400', 'Exception: ' . $exception->getMessage());
            }

        }


    }

}
