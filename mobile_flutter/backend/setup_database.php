<?php
/**
 * Database Setup Script - Q-LESS (SENA CBA)
 * This script recreates the database and tables from scratch
 */

// Database credentials
$host = 'localhost';
$user = 'root';
$pass = '';
$dbname = 'q_less_db';

// Create connection without database
$conn = new mysqli($host, $user, $pass);
if ($conn->connect_error) {
    die("Error de conexión: " . $conn->connect_error);
}

// Drop database if exists
$conn->query("DROP DATABASE IF EXISTS $dbname");

// Create database
$conn->query("CREATE DATABASE $dbname CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci");

// Select database
$conn->select_db($dbname);

// Create users table
$usersTable = "CREATE TABLE users (
    id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    role ENUM('aprendiz', 'instructor', 'admin') NOT NULL DEFAULT 'aprendiz',
    avatar_path VARCHAR(255) NULL,
    description TEXT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_email (email),
    INDEX idx_role (role)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci";

$conn->query($usersTable);

// Create products table
$productsTable = "CREATE TABLE products (
    id INT PRIMARY KEY AUTO_INCREMENT,
    nombre VARCHAR(100) NOT NULL,
    descripcion TEXT NULL,
    precio DECIMAL(10, 2) NOT NULL,
    stock INT NOT NULL DEFAULT 0,
    imagen VARCHAR(255) NULL,
    categoria VARCHAR(50) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_categoria (categoria)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci";

$conn->query($productsTable);

// Create reservations table
$reservationsTable = "CREATE TABLE reservations (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    product_id INT NOT NULL,
    cantidad INT NOT NULL DEFAULT 1,
    fecha_reserva TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    estado ENUM('pendiente', 'confirmada', 'cancelada') NOT NULL DEFAULT 'pendiente',
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
    INDEX idx_user (user_id),
    INDEX idx_product (product_id),
    INDEX idx_estado (estado)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci";

$conn->query($reservationsTable);

// Create orders table
$ordersTable = "CREATE TABLE orders (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    total DECIMAL(10, 2) NOT NULL,
    fecha_pedido TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    estado ENUM('pendiente', 'procesando', 'completado', 'cancelado') NOT NULL DEFAULT 'pendiente',
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_user (user_id),
    INDEX idx_estado (estado)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci";

$conn->query($ordersTable);

// Create admin user (password: 123456)
$adminPassword = password_hash('123456', PASSWORD_BCRYPT);
$adminUser = $conn->prepare("INSERT INTO users (name, email, password, role) VALUES (?, ?, ?, 'admin')");
$adminUser->bind_param('sss', $name, $email, $adminPassword);
$name = 'Admin';
$email = 'admin@local';
$adminUser->execute();
$adminUser->close();

echo "Base de datos recreada exitosamente. Usuario admin creado (email: admin@local, password: 123456)";
$conn->close();
