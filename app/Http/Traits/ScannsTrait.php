<?php

namespace App\Http\Traits;

use Storage;
use Exception;
use Illuminate\Http\Response;

trait ScannsTrait
{

    /**
     * Post new data in audit file
     *
     * @param string $data Data content to add to log file
     * @param string|null $type Type of audit: all, errors, scanner
     *
     * @return array JSON
     */
//    public function createLog($data, $type = null)
//    {
//        $response = new Response();
//        $data = '[' . $_SERVER['REMOTE_ADDR'] . '][' . date('H:i:s') . '] ' . $data;
//
//        try {
//            // set the type if is null
//            if(is_null($type))
//                $auditType = 'all';
//            else
//                $auditType = $type;
//
//            // check if file exists and append the content
//            if(Storage::disk('audits')->has($auditType . '_' . date('Ymd') . '.txt'))
//                Storage::disk('audits')->append($auditType . '_' . date('Ymd') . '.txt', $data);
//            else
//                Storage::disk('audits')->put($auditType . '_' . date('Ymd') . '.txt', $data);
//
//            return response()->json(['message' => 'success'], 200);
//
//        } catch(Exception $exception) {
//            return $response->setStatusCode('400', 'Exception: ' . $exception->getMessage());
//        }
//    }
}