-- Q-LESS Database Creation Script for XAMPP
-- Run this in phpMyAdmin or MySQL command line

-- Create Database
CREATE DATABASE IF NOT EXISTS q_less_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Use the database
USE q_less_db;

-- Unified users table (merge previous 'usuarios' into 'users')
CREATE TABLE IF NOT EXISTS users (
    id INT PRIMARY KEY AUTO_INCREMENT,
    -- general profile info (english/spanish friendly)
    name VARCHAR(100) NOT NULL,
    nombre VARCHAR(100) AS (name) VIRTUAL,
    email VARCHAR(100) NOT NULL UNIQUE,
    correo VARCHAR(100) AS (email) VIRTUAL,
    password VARCHAR(255) NOT NULL,
    role ENUM('aprendiz', 'instructor', 'admin') NOT NULL DEFAULT 'aprendiz',
    telefono VARCHAR(20) NULL,
    direccion TEXT NULL,
    estado VARCHAR(20) NOT NULL DEFAULT 'activo',
    avatar_path VARCHAR(255) NULL,
    description TEXT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_users_email (email),
    INDEX idx_users_role (role),
    INDEX idx_users_estado (estado),
    INDEX idx_users_telefono (telefono)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Products table (user_id uses INT to match users.id). Keep user_id nullable so deleting a user
-- does not remove historical products; instead set to NULL.
CREATE TABLE IF NOT EXISTS productos (
    id INT PRIMARY KEY AUTO_INCREMENT,
    nombre VARCHAR(150) NOT NULL,
    descripcion TEXT NOT NULL,
    categoria VARCHAR(80) NOT NULL DEFAULT 'Cuadernos',
    precio INT NOT NULL DEFAULT 0,
    stock INT NOT NULL DEFAULT 0,
    image_path VARCHAR(255) NULL,
    user_id INT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_product_nombre (nombre),
    INDEX idx_product_categoria (categoria),
    INDEX idx_product_user (user_id),
    CONSTRAINT fk_product_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Orders table (keep history: user and product set to NULL if deleted)
CREATE TABLE IF NOT EXISTS ordenes (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NULL,
    product_id INT NULL,
    product_name VARCHAR(150) NOT NULL,
    quantity INT NOT NULL DEFAULT 1,
    price INT NOT NULL DEFAULT 0,
    total_price INT NOT NULL DEFAULT 0,
    status VARCHAR(50) DEFAULT 'completada',
    product_image_url VARCHAR(255) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_orders_user (user_id),
    INDEX idx_orders_product (product_id),
    INDEX idx_orders_created_at (created_at),
    CONSTRAINT fk_orders_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_orders_product FOREIGN KEY (product_id) REFERENCES productos(id) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Reservations: cascade deletions for users and products (business records should be removed with user/product)
CREATE TABLE IF NOT EXISTS reservations (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    product_id INT NOT NULL,
    quantity INT NOT NULL DEFAULT 1,
    status VARCHAR(20) NOT NULL DEFAULT 'active',
    reserved_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP NULL DEFAULT NULL,
    INDEX idx_res_user (user_id),
    INDEX idx_res_product (product_id),
    INDEX idx_status_expires (status, expires_at),
    CONSTRAINT fk_res_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_res_product FOREIGN KEY (product_id) REFERENCES productos(id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Queues (colas) linked to users: if a user is removed, their queues are removed (cascade)
CREATE TABLE IF NOT EXISTS colas (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    titulo VARCHAR(150) NOT NULL,
    descripcion TEXT NULL,
    cantidad_items INT DEFAULT 0,
    estado VARCHAR(20) DEFAULT 'activa',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_colas_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE ON UPDATE CASCADE,
    INDEX idx_colas_user (user_id),
    INDEX idx_colas_estado (estado)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Items belonging to a cola: cascade when cola is removed
CREATE TABLE IF NOT EXISTS items (
    id INT PRIMARY KEY AUTO_INCREMENT,
    cola_id INT NOT NULL,
    nombre VARCHAR(150) NOT NULL,
    descripcion TEXT NULL,
    cantidad INT DEFAULT 1,
    estado VARCHAR(20) DEFAULT 'pendiente',
    posicion INT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_items_cola FOREIGN KEY (cola_id) REFERENCES colas(id) ON DELETE CASCADE ON UPDATE CASCADE,
    INDEX idx_items_cola (cola_id),
    INDEX idx_items_estado (estado)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- End of schema
