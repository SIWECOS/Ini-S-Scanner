<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Http\Response;
use App\Http\Traits\AuditsTrait;
use App\Http\Traits\ScannsTrait;
use Exception;
use Storage;

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
                            $result = [
                                'name' => 'INI_S',
                                'hasError' => true,
                                'score' => 0,
                                'errorMessage' => [
                                    'placeholder' => 'ERROR',
                                    'values' => (object) [
                                        'Error: ' . $resultsOfScanning['exception']
                                    ]
                                ],
                                'tests' => array()
                            ];
                            $this->createLog('400 Scanning domain [' . $clientDomain . '] return errors:[' . $resultsOfScanning['exception'] . ']', 'errors'); //set error
                        } else {
                            $result = [
                                'name' => 'INI_S',
                                'hasError' => false,
                                'score' => $this->calculateScannerScore($resultsOfScanning['collection']),
                                'errorMessage' => [
                                    'placeholder' => 'NO_ERRORS',
                                    'values' => (object) []
                                ],
                                'tests' => $resultsOfScanning['collection']
                            ];
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
        $result = [];
        ini_set('output_buffering','on');
        ini_set('zlib.output_compression', 0);
        ini_set('max_execution_time', 0);
        ini_set('memory_limit', '2048M');

        try {
            // get configuration files
            $getBlacklists = config('app.blacklists');
            if(is_array($getBlacklists) && !empty($getBlacklists)) {
                //$this->createLog('200 Start refresh blacklists' , 'all');
                $executionStartTime = microtime(true);
                /* PHISHING Section */
                if(is_array($getBlacklists['phishing'])) {
                    $fileContentPhishing = [];
                    $fileContentPhishingErrors = [];
                    foreach($getBlacklists['phishing'] as $provider => $content) {
                        $blacklistData = $this->getBlacklistData($provider, $content['url'], $content['type'], $content['replaceArr'], $content['separator']);
                        if($blacklistData['message'] == 'success')
                            $fileContentPhishing = array_merge($fileContentPhishing, $blacklistData['collection']);
                        else
                            $fileContentPhishingErrors[$provider] = $blacklistData['description'];
                    }
                    if(empty($fileContentPhishingErrors)) {
                        array_unique($fileContentPhishing);
                        sort($fileContentPhishing);
                        // check if file exists and append the content
                        if(Storage::disk('blacklists')->has('phishing.json'))
                            Storage::disk('blacklists')->append('phishing.json', json_encode($blacklistData['collection']));
                        else
                            Storage::disk('blacklists')->put('phishing.json', json_encode($blacklistData['collection']));

                        //$this->createLog('200 Successfully refresh phishing blacklist' , 'all');
                        $result['message']    = 'Successfully refresh phishing blacklist';
                    } else {
                        //$this->createLog('400 Phishing blacklists generate errors: [' . implode(PHP_EOL, $fileContentPhishingErrors) . ']', 'errors'); //set error
                        throw new Exception('Phishing blacklists generate errors: [' . implode(PHP_EOL, $fileContentPhishingErrors) . ']');
                    }
                }

                /* SPAM Section */
                if(is_array($getBlacklists['spam'])) {
                    $fileContentSpam = array();
                    $fileContentSpamErrors = array();
                    foreach($getBlacklists['spam'] as $provider => $content) {
                        $blacklistData = $this->getBlacklistData($provider, $content['url'], $content['type'], $content['replaceArr'], $content['separator']);
                        if($blacklistData['message'] == 'success')
                            $fileContentSpam = array_merge($fileContentSpam, $blacklistData['collection']);
                        else
                            $fileContentSpamErrors[$provider] = $blacklistData['description'];
                    }
                    if(empty($fileContentSpamErrors)) {
                        array_unique($fileContentSpam);
                        sort($fileContentSpam);
                        // check if file exists and append the content
                        if(Storage::disk('blacklists')->has('spam.json'))
                            Storage::disk('blacklists')->append('spam.json', json_encode($blacklistData['collection']));
                        else
                            Storage::disk('blacklists')->put('spam.json', json_encode($blacklistData['collection']));

                        //$this->createLog('200 Successfully refresh spam blacklist' , 'all');
                        $result['message']    = 'Successfully refresh spam blacklist';
                    } else {
                        //$this->createLog('400 Spam blacklists generate errors: [' . implode(PHP_EOL, $fileContentSpamErrors) . ']', 'errors'); //set error
                        throw new Exception('Spam blacklists generate errors: [' . implode(PHP_EOL, $fileContentSpamErrors) . ']');
                    }
                }

                /* MALWARE Section */
                if(is_array($getBlacklists['malware']))
                {
                    $fileContentMalware = array();
                    $fileContentMalwareErrors = array();
                    foreach($getBlacklists['malware'] as $provider => $content)
                    {
                        $blacklistData = $this->getBlacklistData($provider, $content['url'], $content['type'], $content['replaceArr'], $content['separator']);
                        if($blacklistData['message'] == 'success')
                            $fileContentMalware = array_merge($fileContentMalware, $blacklistData['collection']);
                        else
                            $fileContentMalwareErrors[$provider] = $blacklistData['description'];
                    }
                    if(empty($fileContentSpamErrors)) {
                        array_unique($fileContentMalware);
                        sort($fileContentMalware);
                        // check if file exists and append the content
                        if(Storage::disk('blacklists')->has('malware.json'))
                            Storage::disk('blacklists')->append('malware.json', json_encode($blacklistData['collection']));
                        else
                            Storage::disk('blacklists')->put('malware.json', json_encode($blacklistData['collection']));

                        //$this->createLog('200 Successfully refresh malware blacklist' , 'all');
                        $result['message']    = 'Successfully refresh malware blacklist';
                    } else {
                        //$this->createLog('400 Malware blacklists generate errors: [' . implode(PHP_EOL, $fileContentMalwareErrors) . ']', 'errors'); //set error
                        throw new Exception('Malware blacklists generate errors: [' . implode(PHP_EOL, $fileContentMalwareErrors) . ']');
                    }
                }

                $executionEndTime = microtime(true);
                //$this->createLog('200 Stop refresh blacklists, took '. number_format((float)($executionEndTime - $executionStartTime), 4, ',', '') . ' seconds to execute.' , 'all');


            } else {
                //$this->createLog('400 Configuration blacklists is missing or is invalid', 'errors'); //set error
                throw new Exception('Configuration blacklists is missing or is invalid');
            }
        } catch (Exception  $exception) {
            //$this->createLog('Exception #' . $exception->getCode() . ' [' .$exception->getMessage() . ']', 'errors'); //set error
            return $this->response->setStatusCode('400', 'Exception #' . $exception->getCode() . ' [' .$exception->getMessage() . ']');
        }

        return response()->json($result);
    }
}
