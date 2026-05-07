<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        DB::statement('ALTER TABLE cart_reservations MODIFY expires_at DATETIME NOT NULL');
        DB::statement('ALTER TABLE cart_reservations MODIFY purchased_at DATETIME NULL');
    }

    public function down(): void
    {
        DB::statement('ALTER TABLE cart_reservations MODIFY expires_at TIMESTAMP NOT NULL');
        DB::statement('ALTER TABLE cart_reservations MODIFY purchased_at TIMESTAMP NULL');
    }
};
