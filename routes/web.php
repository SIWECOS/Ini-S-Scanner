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

    // <app_url>/audit/now
    Route::get('/now', ['uses' => 'AuditController@index',   'as' => 'all.logs']);



});
