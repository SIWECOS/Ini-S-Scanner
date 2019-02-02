<?php

namespace App\Http\Traits;

use Storage;
use Exception;
use Illuminate\Http\Response;

trait AuditsTrait
{
    /**
     * Get the last content, today, of logs
     *
     * @param string|null $type - Type of audit file
     * @return array JSON
     */
    public function getTodayLog($type = null)
    {
        $response = new Response();

        try {

            if(is_null($type)) { // set the type if is null
                $content = [];
                // check if type all exist and get content
                $auditRequestedFile = 'all_' . date('Ymd') . '.txt';
                if (Storage::disk('audits')->has($auditRequestedFile))
                    $content['all'] = array_values(array_filter(explode(PHP_EOL, Storage::disk('audits')->get($auditRequestedFile))));
                // check if type errors exist and get content
                $auditRequestedFile = 'errors_' . date('Ymd') . '.txt';
                if (Storage::disk('audits')->has($auditRequestedFile))
                    $content['errors'] = array_values(array_filter(explode(PHP_EOL, Storage::disk('audits')->get($auditRequestedFile))));
                // check if type scanner exist and get content
                $auditRequestedFile = 'scanner_' . date('Ymd') . '.txt';
                if (Storage::disk('audits')->has($auditRequestedFile))
                    $content['scanner'] = array_values(array_filter(explode(PHP_EOL, Storage::disk('audits')->get($auditRequestedFile))));
            } else {
                // check if file exists and get the content
                $auditRequestedFile = $type . '_' . date('Ymd') . '.txt';
                if (Storage::disk('audits')->has($auditRequestedFile))
                    $content = array_values(array_filter(explode(PHP_EOL, Storage::disk('audits')->get($auditRequestedFile))));
                else
                    throw new Exception('File ' . $type . '_' . date('Ymd') . '.txt does not exist.');
            }

            return response()->json(['message' => 'success', 'content' => $content], 200);

        } catch(Exception $exception) {
            $this->createLog('Exception #400 Exception: ' . $exception->getMessage(), 'errors'); //set error
            return $response->setStatusCode('400', 'Exception: ' . $exception->getMessage());
        }
    }

    /**
     * Post new data in audit file
     *
     * @param string $data Data content to add to log file
     * @param string|null $type Type of audit: all, errors, scanner
     *
     * @return array JSON
     */
    public static function createLog($data, $type = null)
    {
        $response = new Response();
        $data = '[' . date('H:i:s') . '] ' . $data;

        try {
            // set the type if is null
            if(is_null($type))
                $auditType = 'all';
            else
                $auditType = $type;

            // check if file exists and append the content
            if(Storage::disk('audits')->has($auditType . '_' . date('Ymd') . '.txt'))
                Storage::disk('audits')->append($auditType . '_' . date('Ymd') . '.txt', $data);
            else
                Storage::disk('audits')->put($auditType . '_' . date('Ymd') . '.txt', $data);

            return response()->json(['message' => 'success'], 200);

        } catch(Exception $exception) {
            self::createLog('Exception #400 Exception: ' . $exception->getMessage(), 'errors'); //set error
            return $response->setStatusCode('400', 'Exception: ' . $exception->getMessage());
        }
    }
}