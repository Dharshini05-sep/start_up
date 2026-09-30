<?php
require_once 'db_connect.php';

try {
    // 1. Global latest reading
    $globalStmt = $pdo->query("SELECT * FROM sensor_readings ORDER BY id DESC LIMIT 1");
    $globalRow = $globalStmt->fetch();

    $latestGlobal = null;
    if ($globalRow) {
        $latestGlobal = [
            'temperature'      => $globalRow['temperature'] !== null ? (float)$globalRow['temperature'] : null,
            'humidity'         => $globalRow['humidity'] !== null ? (float)$globalRow['humidity'] : null,
            'source'           => $globalRow['source'],
            'connectionStatus' => $globalRow['connection_status'],
            'timestamp'        => $globalRow['timestamp'],
            'userEmail'        => $globalRow['user_email'],
        ];
    }

    // 2. Latest reading per user (subquery to get max ID per user_email)
    $userStmt = $pdo->query("
        SELECT sr.*
        FROM sensor_readings sr
        INNER JOIN (
            SELECT MAX(id) as max_id
            FROM sensor_readings
            WHERE user_email IS NOT NULL AND user_email != ''
            GROUP BY user_email
        ) latest ON sr.id = latest.max_id
    ");
    $userRows = $userStmt->fetchAll();

    $userReadings = [];
    foreach ($userRows as $row) {
        $email = strtolower($row['user_email']);
        $userReadings[$email] = [
            'temperature'      => $row['temperature'] !== null ? (float)$row['temperature'] : null,
            'humidity'         => $row['humidity'] !== null ? (float)$row['humidity'] : null,
            'source'           => $row['source'],
            'connectionStatus' => $row['connection_status'],
            'timestamp'        => $row['timestamp'],
            'userEmail'        => $row['user_email'],
        ];
    }

    echo json_encode([
        'status' => 'success',
        'latestGlobal' => $latestGlobal,
        'userReadings' => $userReadings
    ]);
} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode(['status' => 'error', 'message' => 'Database error: ' . $e->getMessage()]);
}
?>
