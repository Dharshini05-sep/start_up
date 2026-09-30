<?php
require_once 'db_connect.php';

$raw = file_get_contents('php://input');
$data = json_decode($raw, true);

if (!$data) {
    http_response_code(400);
    echo json_encode(['status' => 'error', 'message' => 'Invalid JSON input']);
    exit();
}

$userEmail        = !empty($data['userEmail']) ? strtolower(trim($data['userEmail'])) : null;
$temperature      = isset($data['temperature']) && is_numeric($data['temperature']) ? (float)$data['temperature'] : null;
$humidity         = isset($data['humidity']) && is_numeric($data['humidity']) ? (float)$data['humidity'] : null;
$source           = trim($data['source'] ?? 'Bluetooth');
$connectionStatus = trim($data['connectionStatus'] ?? 'Connected');
$timestamp        = trim($data['timestamp'] ?? date('Y-m-d H:i:s'));

try {
    $stmt = $pdo->prepare("
        INSERT INTO sensor_readings (user_email, temperature, humidity, source, connection_status, timestamp)
        VALUES (?, ?, ?, ?, ?, ?)
    ");
    $stmt->execute([
        $userEmail,
        $temperature,
        $humidity,
        $source,
        $connectionStatus,
        $timestamp
    ]);

    echo json_encode([
        'status' => 'success',
        'message' => 'Sensor reading stored successfully in MySQL.',
        'readingId' => $pdo->lastInsertId()
    ]);
} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode(['status' => 'error', 'message' => 'Database error: ' . $e->getMessage()]);
}
?>
