<?php

/*
|--------------------------------------------------------------------------
| Web Routes
|--------------------------------------------------------------------------
|
| Here is where you can register web routes for your application. These
| routes are loaded by the RouteServiceProvider within a group which
| contains the "web" middleware group. Now create something great!
|
*/

Route::get('/', function () {
    return view('welcome');
});

// Audit routes
Route::group(['prefix' => 'audit'], function() {

    // <app_url>/audit/today/{type} -> {type} is optional
    Route::get('/today/{type?}', ['uses' => 'AuditController@today',   'as' => 'today.logs']);

});

// Audit routes
Route::group(['prefix' => 'scanner'], function() {

    // <app_url>/scanner/testare
    Route::get('/testare', ['uses' => 'ScannerController@testare',   'as' => 'testare.scanner']);

});
