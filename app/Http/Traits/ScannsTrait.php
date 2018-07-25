<?php

namespace App\Http\Traits;

use Storage;
use Exception;

trait ScannsTrait
{

    /**
     * Return scanning results
     *
     * @param string $url Domain sent for scanning
     * @param array $scanChecks Array with scanner checks
     * @return array
     */
    public function getScannerResults($url, $scanChecks)
    {
        $result = array();

        try {
            foreach($scanChecks as $scanCheck)
            {
                // check if domain is present in specific blacklist
                $searchUrl = $this->searchUrl($scanCheck, $url);
                if(isset($searchUrl['message']) && $searchUrl['message'] == 'fail')
                    throw new Exception($searchUrl['exception']);
                else
                    $result['collection'][] = $searchUrl['collection'];
            }
        } catch (Exception $exception) {
            $result['message']     = 'fail';
            $result['exception'] = 'Exception [' . $exception->getMessage() . ']';
            $result['exception'] .= (is_null($exception->getFile())) ? '' : ' in file [' . $exception->getFile() . ']';
            $result['exception'] .= (is_null($exception->getLine())) ? '' : ', line: ' . $exception->getLine();
        }

        return $result;
    }

    /**
     * Check if url is present in specific scanning results file.
     *
     * @param string $file File name
     * @param string $url Url for extract data
     *
     * @return array
     */
    public function searchUrl( $file, $url ) {
        $result       = array();
        $scanTestName = $file;
        $file         = $file . '.json';

        try {
            if (Storage::disk('blacklists')->has($file)) {
                $scanArray     = json_decode( Storage::disk('blacklists')->get($file) );
                $filteredArray = array_filter( $scanArray, function ( $element ) use ( $url ) {
                    if ( isset( $element ) ) {
                        // avoid results with the url included in another url (ex.: test.de and abntest.de)
                        $splitElement = explode( '/', $element ); // check if element is a long url
                        if ( isset( $splitElement ) && is_array( $splitElement ) ) {
                            $hostDomain = parse_url('http://' . $element, PHP_URL_HOST);
                            if ( in_array( $url, $splitElement ) && $hostDomain === $url ) {
                                return $element;
                            }
                        } else {
                            if ( strpos( $element, $url ) !== false ) {
                                return $element;
                            }
                        }
                    }
                } );
                if ( is_array( $filteredArray ) && count( $filteredArray ) > 0 ) {
                    $result['collection']['name']         = strtoupper( $scanTestName );
                    $result['collection']['hasError']     = false;
                    $result['collection']['dangerlevel']  = 0;
                    $result['collection']['errorMessage'] = array(
                        'placeholder' => 'NO_ERRORS',
                        'values' => (object) array()
                    );
                    $result['collection']['score']         = 0;
                    $result['collection']['scoreType']    = 'warning';
                    $tempTestDetails['placeholder'] = strtoupper($scanTestName) . '_FOUND';
                    $tempTestDetails['values']['site'] = $url;
                    $tempWhere = array();
                    foreach ( $filteredArray as $occurence ) {
                        $tempWhere[] = $occurence;
                    }
                    $tempTestDetails['values']['where'] = implode(', ', $tempWhere);
                    $result['collection']['testDetails'][]  = (object) $tempTestDetails;
                    $this->createLog('200 Found occurences in the blacklist [' . strtoupper($scanTestName) . '] for the url [' . $url . ']' , 'scanner');
                } else {
                    $result['collection']['name']         = strtoupper( $scanTestName );
                    $result['collection']['hasError']     = false;
                    $result['collection']['dangerlevel']  = 0;
                    $result['collection']['errorMessage'] = array(
                        'placeholder' => 'NO_ERRORS',
                        'values' => (object) array()
                    );
                    $result['collection']['score']        = 100;
                    $result['collection']['scoreType']    = 'success';
                    $result['collection']['testDetails']  = array();
                    $this->createLog('200 No occurences in the blacklist [' . strtoupper($scanTestName) . '] for the url [' . $url . ']' , 'scanner');
                }
            } else {
                throw new Exception( 'File [' . $file . '] doesn\'t exist.' );
            }
        } catch ( Exception $exception ) {
            $result['message']     = 'fail';
            $result['exception'] = 'Exception [' . $exception->getMessage() . ']';
            $result['exception'] .= (is_null($exception->getFile())) ? '' : ' in file [' . $exception->getFile() . ']';
            $result['exception'] .= (is_null($exception->getLine())) ? '' : ', line: ' . $exception->getLine();
        }

        return $result;
    }

    /**
     * Return API Callback.
     *
     * @param array $callbackurls Array with urls where API wait for return
     * @param string $type String with message type: Success or Error
     * @param array $answer Json object with message
     *
     * @return void
     */
    public function notifyCallbacks( $callbackurls, $type, $answer ) {
        if ( $type === 'error' ) {
            $result = array(
                'name' => 'INI-S',
                'hasError' => true,
                'errorMessage' => array( $answer )
            );
            header( 'Content-Type: application/json; charset=utf-8' );
            echo json_encode( $result, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES );
        } else {
            if(count($callbackurls) > 0) {
                foreach ( $callbackurls as $url ) {
                    try {
                        $data_string = json_encode( $answer );

                        $ch = curl_init( $url );
                        curl_setopt( $ch, CURLOPT_CUSTOMREQUEST, "POST" );
                        curl_setopt( $ch, CURLOPT_POSTFIELDS, $data_string );
                        curl_setopt( $ch, CURLOPT_RETURNTRANSFER, true );
                        curl_setopt( $ch, CURLOPT_HTTPHEADER, array(
                                'Content-Type: application/json',
                                'Content-Length: ' . strlen( $data_string )
                            )
                        );

                        $result = curl_exec( $ch );
                    } catch ( Exception $exception ) {
                        $message = 'Exception [' . $exception->getMessage() . ']';
                        $message .= ( is_null( $exception->getFile() ) ) ? '' : ' in file' . $exception->getFile();
                        $message .= ( is_null( $exception->getLine() ) ) ? '' : ', line: ' . $exception->getLine();
                        $result  = array(
                            'http_errors' => true,
                            'timeout'     => 60,
                            'json'        => array( $message )
                        );
                        header( 'Content-Type: application/json; charset=utf-8' );
                        echo json_encode( $result, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES );
                    }
                }
            } else {
                header( 'Content-Type: application/json; charset=utf-8' );
                header( 'Content-Length: ' . strlen(json_encode( $answer )) );
                echo json_encode( $answer, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES );
            }

        }
    }

    /**
     * Calculation of scanner score.
     *
     * @param array $scanChecks Array with scanchecks results
     *
     * @return integer
     */
    public function calculateScannerScore( $scanChecks ) {
        if(is_array($scanChecks)) {
            $riskTotal = 0;
            foreach($scanChecks as $scanCheck){
                $riskTotal += $scanCheck['score'];
            }
            return $riskTotal/count($scanChecks);
        } else {
            return 0;
        }
    }
}