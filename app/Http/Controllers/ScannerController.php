<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Http\Response;
use App\Http\Traits\AuditsTrait;
use App\Http\Traits\ScannsTrait;
use Exception;

class ScannerController extends Controller
{
    use AuditsTrait, ScannsTrait;
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
     * Proceed to scan an url, based on post params
     * consume a specific Json array
     *  {
     *    "url": "string",
     *    "dangerLevel": 0,
     *    "callbackurls": [
     *          "string"
     *    ]
     *  }
     *
     * @param Request $request - data sent by http request
     * @return array JSON
     * @throws Exception
     */
    public function start(Request $request)
    {
        $result = array();

        try {
            //check and validate the post request
            if ( is_null($request->all()) ) {
                return $this->response->setStatusCode('400', 'Invalid body from POST request');
            } else {
                if ( empty( $request->url ) || !is_string($request->url) || strlen( parse_url( $request->url, PHP_URL_HOST ) ) < 1 ) {
                    return $this->response->setStatusCode('400', 'No URL is set or given');
                } else {
                    if ( !is_array( $request->callbackurls )) {
                        return $this->response->setStatusCode('400', 'No CallBackURLs is set or given');
                    } else {
                        // all ok, start scanning
                        $clientDomain = parse_url( $request->url, PHP_URL_HOST );
                    }
                }
            }

        } catch (Exception  $exception) {
            $result['exception'] = 'Exception #' . $exception->getCode() . ' [' .$exception->getMessage() . ']';
        }

        return response()->json($clientDomain);
    }

    /**
     * Get the last content, today, of logs
     *
     * @param Request $request - data sent by http request
     * @return array JSON
     */
    public function testare(Request $request)
    {
        return $this->createLog('testare ' . date('His'));
    }



}
