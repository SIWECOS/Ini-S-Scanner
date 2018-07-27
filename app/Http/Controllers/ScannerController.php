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
     * @return Response
     * @throws Exception
     */
    public function start(Request $request)
    {

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
                        $this->createLog('200 START SCAN - domain [' . $clientDomain . ']' , 'scanner');
                        $resultsOfScanning = $this->getScannerResults($clientDomain, config('app.scannerChecks'));
                        $executionEndTime = microtime(true);
                        $this->createLog('200 STOP SCAN - scanning domain [' . $clientDomain . '] took '. number_format((float)($executionEndTime - $executionStartTime), 4, ',', '') . ' seconds to execute.' , 'scanner');
                        // check the callbacks and return the scanning results
                        if(isset($resultsOfScanning['message']) && $resultsOfScanning['message'] == 'fail') {
                            $result = array(
                                'name' => 'INI_S',
                                'hasError' => true,
                                'score' => 0,
                                'errorMessage' => array(
                                    'placeholder' => 'ERROR',
                                    'values' => (object) array(
                                        'Error: ' . $resultsOfScanning['exception']
                                    )
                                ),
                                'tests' => array()
                            );
                            $this->createLog('400 Scanning domain [' . $clientDomain . '] return errors:[' . $resultsOfScanning['exception'] . ']', 'errors'); //set error
                        } else {
                            $result = array(
                                'name' => 'INI_S',
                                'hasError' => false,
                                'score' => $this->calculateScannerScore($resultsOfScanning['collection']),
                                'errorMessage' => array(
                                    'placeholder' => 'NO_ERRORS',
                                    'values' => (object) array()
                                ),
                                'tests' => $resultsOfScanning['collection']
                            );
                        }

                        $this->createLog('200 Send back to the callbackUrls the scanning results' , 'scanner');
                        $this->notifyCallbacks( $request->callbackurls, 'success', $result );
                    }
                }
            }

        } catch (Exception  $exception) {
            $this->createLog('Exception #' . $exception->getCode() . ' [' .$exception->getMessage() . ']', 'errors'); //set error
            return $this->response->setStatusCode('400', 'Exception #' . $exception->getCode() . ' [' .$exception->getMessage() . ']');
        }

    }

    /**
     * Update the blacklists, using a cron job
     *
     * @param Request $request - data sent by http request
     * @return Response
     * @throws Exception
     */
    public function updateBlacklists(Request $request)
    {
        return $this->response('testing testing testing')->setStatusCode('200', 'Testing update');
    }
}
