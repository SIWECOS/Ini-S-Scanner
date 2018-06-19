<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Carbon\Carbon;

class AuditController extends Controller
{
    /**
     * Get all active unitati, including parent, departament
     * Browse our Data Type (B)READ
     *
     * @return array JSON
     */
    public function index()
    {
        return response()->json(['message' => 'Test'], 401);
    }

}
