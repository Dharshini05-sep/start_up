-- Database Schema for LoRa Sensor Monitoring Application
CREATE DATABASE IF NOT EXISTS `lora_sensor_db` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE `lora_sensor_db`;

-- Users Table
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

-- Sensor Readings Table
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
