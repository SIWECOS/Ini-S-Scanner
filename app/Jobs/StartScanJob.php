<?php

namespace App\Jobs;

use App\Http\Traits\AuditsTrait;
use App\Http\Traits\ScannsTrait;
use Illuminate\Bus\Queueable;
use Illuminate\Queue\SerializesModels;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;

class StartScanJob implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public $url;
    public $callbackurls;

    /**
     * Create a new job instance.
     *
     * @return void
     */
    public function __construct($url, $callbackurls)
    {
        $this->url = $url;
        $this->callbackurls = $callbackurls;
    }

    /**
     * Execute the job.
     *
     * @return void
     */
    public function handle()
    {
        $clientDomain = parse_url($this->url, PHP_URL_HOST);
        $executionStartTime = microtime(true);
        AuditsTrait::createLog('200 START SCAN - domain [' . $clientDomain . ']', 'scanner');
        $resultsOfScanning = ScannsTrait::getScannerResults($clientDomain, config('app.scannerChecks'));
        $executionEndTime = microtime(true);
        AuditsTrait::createLog('200 STOP SCAN - scanning domain [' . $clientDomain . '] took ' . number_format((float)($executionEndTime - $executionStartTime), 4, ',', '') . ' seconds to execute.', 'scanner');
        // check the callbacks and return the scanning results
        if (isset($resultsOfScanning['message']) && $resultsOfScanning['message'] == 'fail') {
            $result = [
                'name' => 'INI_S',
                'hasError' => true,
                'score' => 0,
                'errorMessage' => [
                    'placeholder' => 'ERROR',
                    'values' => (object)[
                        'Error: ' . $resultsOfScanning['exception']
                    ]
                ],
                'tests' => array()
            ];
            AuditsTrait::createLog('400 Scanning domain [' . $clientDomain . '] return errors:[' . $resultsOfScanning['exception'] . ']', 'errors'); //set error
        } else {
            $result = [
                'name' => 'INI_S',
                'hasError' => false,
                'score' => ScannsTrait::calculateScannerScore($resultsOfScanning['collection']),
                'errorMessage' => null,
                'tests' => $resultsOfScanning['collection']
            ];
        }

        AuditsTrait::createLog('200 Send back to the callbackUrls the scanning results', 'scanner');
        ScannsTrait::notifyCallbacks($this->callbackurls, 'success', $result);
    }
}
