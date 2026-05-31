<?php
// Configuración de la base de datos
date_default_timezone_set('America/Bogota');

$host = 'localhost';
$user = 'root';
$pass = '';
$db   = 'q_less_db';
$port = 3306;

// Crear conexión sin imprimir nada
$conn = new mysqli($host, $user, $pass, $db, $port);

// Si falla, solo terminamos el script en silencio o devolvemos un error limpio
if ($conn->connect_error) {
    // No usamos echo aquí, lo manejaremos en el login.php si es necesario
    exit; 
}

$conn->set_charset("utf8mb4");
?>