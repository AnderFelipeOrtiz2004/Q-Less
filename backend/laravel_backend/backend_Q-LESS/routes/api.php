<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\AuthController;
use App\Http\Controllers\CartController;
use App\Http\Controllers\CategoriaController;
use App\Http\Controllers\ChatbotController;
use App\Http\Controllers\ProductoController;

Route::post('/register', [AuthController::class, 'register']);
Route::post('/login', [AuthController::class, 'login']);
Route::post('/logout', [AuthController::class, 'logout']);
Route::get('/categorias', [CategoriaController::class, 'index']);
Route::post('/chatbot/recomendar', [ChatbotController::class, 'recommend']);
Route::get('/carrito/{userId}', [CartController::class, 'index']);
Route::post('/carrito/reservar', [CartController::class, 'reserve']);
Route::patch('/carrito/{userId}/{productId}/decrease', [CartController::class, 'decrease']);
Route::delete('/carrito/{userId}/{productId}', [CartController::class, 'remove']);
Route::delete('/carrito/{userId}', [CartController::class, 'clear']);
Route::post('/carrito/checkout', [CartController::class, 'checkout']);
Route::apiResource('productos', ProductoController::class);
