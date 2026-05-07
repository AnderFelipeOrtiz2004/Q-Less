<?php

namespace App\Http\Controllers;

use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;

class AuthController extends Controller
{
    private string $adminEmail = 'daniandrescubidesh@gmail.com';

    public function register(Request $request)
    {
        $request->validate([
            'name' => 'required|string|max:255',
            'email' => 'required|string|email|max:255|unique:users',
            'telefono' => 'required|string|max:30',
            'password' => 'required|string|min:8',
        ]);

        $user = User::create([
            'name' => $request->name,
            'email' => $request->email,
            'telefono' => $request->telefono,
            'rol' => $request->email === $this->adminEmail ? 'admin' : 'usuario',
            'password' => Hash::make($request->password),
        ]);

        return response()->json([
            'status' => true,
            'message' => 'Usuario registrado correctamente',
            'token' => Str::random(64),
            'user' => $user,
        ]);
    }

    public function login(Request $request)
    {
        $request->validate([
            'email' => 'required|email',
            'password' => 'required',
        ]);

        $user = User::where('email', $request->email)->first();

        if (!$user) {
            return response()->json([
                'message' => 'Usuario no existe',
            ], 404);
        }

        if (!Hash::check($request->password, $user->password)) {
            return response()->json([
                'message' => 'Contrasena incorrecta',
            ], 401);
        }

        $role = $user->email === $this->adminEmail ? 'admin' : 'usuario';

        if ($user->rol !== $role) {
            $user->rol = $role;
            $user->save();
        }

        return response()->json([
            'status' => true,
            'message' => 'Login exitoso',
            'token' => Str::random(64),
            'user' => $user,
            'role' => $role,
        ]);
    }

    public function logout()
    {
        return response()->json([
            'status' => true,
            'message' => 'Sesion cerrada',
        ]);
    }
}
