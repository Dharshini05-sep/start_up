<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");

$host = 'localhost';
$port = 3306;
$user = 'root';
$pass = '';

try {
    // Connect to MySQL server without database
    $pdo = new PDO("mysql:host=$host;port=$port;charset=utf8mb4", $user, $pass, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION
    ]);

    // 1. Create Database
    $pdo->exec("CREATE DATABASE IF NOT EXISTS `lora_sensor_db` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;");
    $pdo->exec("USE `lora_sensor_db`;");

    // 2. Create Users Table
    $pdo->exec("
        CREATE TABLE IF NOT EXISTS `users` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `first_name` VARCHAR(100) NOT NULL,
            `last_name` VARCHAR(100) NOT NULL,
            `email` VARCHAR(191) NOT NULL UNIQUE,
            `account_type` VARCHAR(50) NOT NULL,
            `password_hash` VARCHAR(255) NOT NULL,
            `salt` VARCHAR(100) NOT NULL,
            `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ");

    // 3. Create Sensor Readings Table
    $pdo->exec("
        CREATE TABLE IF NOT EXISTS `sensor_readings` (
            `id` INT AUTO_INCREMENT PRIMARY KEY,
            `user_email` VARCHAR(191) NULL,
            `temperature` DOUBLE NULL,
            `humidity` DOUBLE NULL,
            `source` VARCHAR(50) NOT NULL,
            `connection_status` VARCHAR(50) NOT NULL,
            `timestamp` DATETIME DEFAULT CURRENT_TIMESTAMP,
            INDEX `idx_user_email` (`user_email`),
            INDEX `idx_timestamp` (`timestamp`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ");

    echo json_encode([
        'status' => 'success',
        'message' => 'Database "lora_sensor_db" and tables (users, sensor_readings) initialized successfully!'
    ]);
} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode([
        'status' => 'error',
        'message' => 'Database initialization failed: ' . $e->getMessage()
    ]);
}
?>
