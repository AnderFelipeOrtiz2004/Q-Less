<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Producto extends Model
{
    protected $table = 'productos';

    protected $fillable = [
        'nombre',
        'descripcion',
        'precio',
        'stock',
        'image_path',
        'categoria',
        'categoria_id',
        'user_id',
    ];

    public function categoriaRelacion()
    {
        return $this->belongsTo(Categoria::class, 'categoria_id');
    }

    public function usuario()
    {
        return $this->belongsTo(User::class, 'user_id');
    }
}
