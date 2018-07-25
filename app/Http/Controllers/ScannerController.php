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
                $this->createLog('400 Invalid body from POST request', 'errors'); //set error
                return $this->response->setStatusCode('400', 'Invalid body from POST request');
            } else {
                if ( empty( $request->url ) || !is_string($request->url) || strlen( parse_url( $request->url, PHP_URL_HOST ) ) < 1 ) {
                    $this->createLog('400 No URL is set or given', 'errors'); //set error
                    return $this->response->setStatusCode('400', 'No URL is set or given');
                } else {
                    if ( !is_array( $request->callbackurls )) {
                        $this->createLog('400 No CallBackURLs is set or given', 'errors'); //set error
                        return $this->response->setStatusCode('400', 'No CallBackURLs is set or given');
                    } else {
                        // all ok, start scanning
                        $clientDomain = parse_url( $request->url, PHP_URL_HOST );
                        $executionStartTime = microtime(true);
                        $this->createLog('200 Start scan domain [' . $clientDomain . ']' , 'scanner');
                        $resultsOfScanning = $this->getScannerResults($clientDomain, config('app.scannerChecks'));
                        $executionEndTime = microtime(true);
                        $this->createLog('200 Stop scan domain [' . $clientDomain . '], took '. ($executionEndTime - $executionStartTime) . 'seconds to execute.' , 'scanner');
                    }
                }
            }

        } catch (Exception  $exception) {
            $this->createLog('Exception #' . $exception->getCode() . ' [' .$exception->getMessage() . ']', 'errors'); //set error
            $result['exception'] = 'Exception #' . $exception->getCode() . ' [' .$exception->getMessage() . ']';
        }

        return response()->json($resultsOfScanning);
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
