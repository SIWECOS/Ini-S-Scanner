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
    public static function getScannerResults($url, $scanChecks)
    {
        $result = array();

        try {
            foreach($scanChecks as $scanCheck)
            {
                // check if domain is present in specific blacklist
                $searchUrl = self::searchUrl($scanCheck, $url);
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
    public static function searchUrl( $file, $url ) {
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
                    AuditsTrait::createLog('200 Found occurences in the blacklist [' . strtoupper($scanTestName) . '] for the url [' . $url . ']' , 'scanner');
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
                    AuditsTrait::createLog('200 No occurences in the blacklist [' . strtoupper($scanTestName) . '] for the url [' . $url . ']' , 'scanner');
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
    public static function notifyCallbacks( $callbackurls, $type, $answer ) {
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
    public static function calculateScannerScore( $scanChecks ) {
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

    /**
     * Get data from a provider.
     *
     * @param string $provider Provider name
     * @param string $url Url for extract data
     * @param string|bool $type The type of extraction (gzip, array, line, etc.) - false by default
     * @param array|bool $replaceArr The protocols which need to be crop it down (http, https, etc.) - false by default
     * @param string $separator The separator for lines in text file - "\r\n" by default
     *
     * @return array
     */
    public function getBlacklistData( $provider, $url, $type = false, $replaceArr = false, $separator = "\r\n" ) {
        $result = array();

        try {
            if ( is_null( $provider ) || strlen( $provider ) < 1 ) {
                throw new Exception( 'Provider didn\'t set.' );
            }

            switch ( $provider ) {
                case 'phishtank':
                    $getProviderData = gzfile( $url );
                    if ( is_array( $getProviderData ) ) {
                        $result['message']    = 'success';
                        $result['collection'] = array();
                        $tmpData              = json_decode( implode( $getProviderData ), true );
                        foreach ( $tmpData as $line ) {
                            if ( $line['verified'] == 'yes' ) {
                                $result['collection'][] = utf8_encode( str_replace( $replaceArr, '', $line['url'] ) );
                            }
                        }
                        array_unique( $result['collection'] );
                        sort( $result['collection'] );
                    } else {
                        throw new Exception( 'Provider data invalid.' );
                    }
                    break;
                case 'hosts-file-phish':
                case 'hosts-file-emd':
                case 'hosts-file-exp':
                case 'hosts-file-fsa':
                case 'hosts-file-hjk':
                case 'hosts-file-wrz':
                    $getProviderData = $this->getRemoteData( $url );
                    if ( is_string( $getProviderData ) ) {
                        $result['message']    = 'success';
                        $result['collection'] = array();
                        $line                 = strtok( $getProviderData, $separator );
                        while ( $line !== false ) {
                            if ( $line[0] !== '#' ) {
                                $lineSplit = preg_split( '/\s+/', $line );
                                if ( $lineSplit[1] !== 'localhost' ) {
                                    $result['collection'][] = utf8_encode( $lineSplit[1] );
                                }
                            }
                            $line = strtok( $separator );
                        }
                        array_unique( $result['collection'] );
                        sort( $result['collection'] );
                    } else {
                        throw new Exception( 'Provider data invalid.' );
                    }
                    break;
                case 'openphish':
                    $getProviderData = $this->getRemoteData( $url );
                    if ( is_string( $getProviderData ) ) {
                        $result['message']    = 'success';
                        $result['collection'] = array();
                        $line                 = strtok( $getProviderData, $separator );
                        while ( $line !== false ) {
                            $result['collection'][] = utf8_encode( str_replace( $replaceArr, '', $line ) );
                            $line                   = strtok( $separator );
                        }
                        array_unique( $result['collection'] );
                        sort( $result['collection'] );
                    } else {
                        throw new Exception( 'Provider data invalid.' );
                    }
                    break;
                case 'joewein':
                    $getProviderData = $this->getRemoteData( $url );
                    if ( is_string( $getProviderData ) ) {
                        $result['message']    = 'success';
                        $result['collection'] = array();
                        $line                 = strtok( $getProviderData, $separator );
                        while ( $line !== false ) {
                            $lineSplit = explode( ';', $line );
                            if ( is_array( $lineSplit ) && count( $lineSplit ) > 0 ) {
                                $result['collection'][] = utf8_encode( $lineSplit[0] );
                            } else {
                                $result['collection'][] = utf8_encode( trim( $line ) );
                            }
                            $line = strtok( $separator );
                        }
                        array_unique( $result['collection'] );
                        sort( $result['collection'] );
                    } else {
                        throw new Exception( 'Provider data invalid.' );
                    }
                    break;
                case 'bambenekconsulting':
                    $getProviderData = $this->getRemoteData( $url );
                    if ( is_string( $getProviderData ) ) {
                        $result['message']    = 'success';
                        $result['collection'] = array();
                        $line                 = strtok( $getProviderData, $separator );
                        while ( $line !== false ) {
                            if ( $line[0] !== '#' ) {
                                $lineSplit              = explode( ',', $line );
                                $result['collection'][] = utf8_encode( $lineSplit[0] );
                            }
                            $line = strtok( $separator );
                        }
                        array_unique( $result['collection'] );
                        sort( $result['collection'] );
                    } else {
                        throw new Exception( 'Provider data invalid.' );
                    }
                    break;
                case 'malwaredomainlist':
                    $getProviderData = $this->getRemoteData( $url );
                    if ( is_string( $getProviderData ) ) {
                        $result['message']    = 'success';
                        $result['collection'] = array();
                        $line                 = strtok( $getProviderData, $separator );
                        while ( $line !== false ) {
                            if ( $line[0] !== '#' ) {
                                $result['collection'][] = utf8_encode( trim( str_replace( '127.0.0.1', '', $line ) ) );
                            }
                            $line = strtok( $separator );
                        }
                        array_unique( $result['collection'] );
                        sort( $result['collection'] );
                    } else {
                        throw new Exception( 'Provider data invalid.' );
                    }
                    break;
                case 'ransomwaretracker':
                    $getProviderData = $this->getRemoteData( $url );
                    if ( is_string( $getProviderData ) ) {
                        $result['message']    = 'success';
                        $result['collection'] = array();
                        $line                 = strtok( $getProviderData, $separator );
                        while ( $line !== false ) {
                            if ( $line[0] !== '#' ) {
                                $result['collection'][] = utf8_encode( str_replace( $replaceArr, '', $line ) );
                            }
                            $line = strtok( $separator );
                        }
                        array_unique( $result['collection'] );
                        sort( $result['collection'] );
                    } else {
                        throw new Exception( 'Provider data invalid.' );
                    }
                    break;
                case 'zeustracker':
                    $getProviderData = $this->getRemoteData( $url );
                    if ( is_string( $getProviderData ) ) {
                        $result['message']    = 'success';
                        $result['collection'] = array();
                        $line                 = strtok( $getProviderData, $separator );
                        while ( $line !== false ) {
                            if ( $line[0] !== '#' ) {
                                $result['collection'][] = utf8_encode( trim( $line ) );
                            }
                            $line = strtok( $separator );
                        }
                        array_unique( $result['collection'] );
                        sort( $result['collection'] );
                    } else {
                        throw new Exception( 'Provider data invalid.' );
                    }
                    break;
                default:
                    throw new Exception( 'Provider didn\'t found in config array.' );
            }
        } catch ( Exception $exception ) {
            $result['message']     = 'fail';
            $result['description'] = 'Exception [' . $exception->getMessage() . ']';
            $result['description'] .= ( is_null( $exception->getFile() ) ) ? '' : ' in file' . $exception->getFile();
            $result['description'] .= ( is_null( $exception->getLine() ) ) ? '' : ', line: ' . $exception->getLine();
        }

        return $result;
    }

    /**
     * Get remote data with curl.
     *
     * @param string $url Remote url
     * @param string|boolean $postParams Post parameters
     *
     * @return mixed
     */
    public function getRemoteData( $url, $postParams = false ) {
        $curl = curl_init();
        curl_setopt( $curl, CURLOPT_URL, $url );
        curl_setopt( $curl, CURLOPT_RETURNTRANSFER, 1 );
        if ( $postParams ) {
            curl_setopt( $curl, CURLOPT_POST, true );
            curl_setopt( $curl, CURLOPT_POSTFIELDS, "var1=bla&" . $postParams );
        }
        curl_setopt( $curl, CURLOPT_SSL_VERIFYHOST, false );
        curl_setopt( $curl, CURLOPT_SSL_VERIFYPEER, false );
        curl_setopt( $curl, CURLOPT_USERAGENT, "Mozilla/5.0 (Windows NT 6.1; rv:33.0) Gecko/20100101 Firefox/33.0" );
        curl_setopt( $curl, CURLOPT_COOKIE, 'CookieName1=Value;' );
        curl_setopt( $curl, CURLOPT_MAXREDIRS, 10 );
        $followAllowed = ( ini_get( 'open_basedir' ) || ini_get( 'safe_mode' ) ) ? false : true;
        if ( $followAllowed ) {
            curl_setopt( $curl, CURLOPT_FOLLOWLOCATION, 1 );
        }
        curl_setopt( $curl, CURLOPT_CONNECTTIMEOUT, 9 );
        curl_setopt( $curl, CURLOPT_REFERER, $url );
        curl_setopt( $curl, CURLOPT_TIMEOUT, 60 );
        curl_setopt( $curl, CURLOPT_AUTOREFERER, true );
        curl_setopt( $curl, CURLOPT_ENCODING, 'gzip,deflate' );
        $data   = curl_exec( $curl );
        $status = curl_getinfo( $curl );
        curl_close( $curl );
        preg_match( '/(http(|s)):\/\/(.*?)\/(.*\/|)/si', $status['url'], $link );
        $data = preg_replace( '/(src|href|action)=(\'|\")((?!(http|https|javascript:|\/\/|\/)).*?)(\'|\")/si', '$1=$2' . $link[0] . '$3$4$5', $data );
        $data = preg_replace( '/(src|href|action)=(\'|\")((?!(http|https|javascript:|\/\/)).*?)(\'|\")/si', '$1=$2' . $link[1] . '://' . $link[3] . '$3$4$5', $data );
        if ( $status['http_code'] == 200 ) {
            return $data;
        } elseif ( $status['http_code'] == 301 || $status['http_code'] == 302 ) {
            if ( ! $followAllowed ) {
                if ( ! empty( $status['redirect_url'] ) ) {
                    $redirURL = $status['redirect_url'];
                } else {
                    preg_match( '/href\=\"(.*?)\"/si', $data, $match );
                    if ( ! empty( $match[1] ) ) {
                        $redirURL = $match[1];
                    }
                }
                if ( ! empty( $redirURL ) ) {
                    return call_user_func( __FUNCTION__, $redirURL, $postParams );
                }
            }
        }

        return "ERROR CODE 22 with $url!!<br/>Last status codes<b/>: " . json_encode( $status ) . "<br/><br/>Last data got<br/>: $data";
    }
}