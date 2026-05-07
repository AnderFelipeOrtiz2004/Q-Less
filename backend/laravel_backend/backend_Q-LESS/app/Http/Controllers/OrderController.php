<?php

namespace App\Http\Controllers;

use App\Models\Order;
use Illuminate\Http\Request;

class OrderController extends Controller
{
    public function index()
    {
        $orders = Order::with('user')
            ->latest()
            ->get();

        return response()->json([
            'status' => true,
            'orders' => $orders
        ]);
    }
public function updateStatus(Request $request, $id)
{
    $request->validate([
        'status' => 'required|string'
    ]);

    $order = Order::findOrFail($id);

    $order->status = $request->status;

    $order->save();

    return response()->json([
        'status' => true,
        'message' => 'Estado actualizado.',
        'order' => $order
    ]);
}
}