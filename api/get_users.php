<?php
require_once 'db_connect.php';

try {
    $stmt = $pdo->query("SELECT id, first_name, last_name, email, account_type, password_hash, salt, created_at FROM users ORDER BY id DESC");
    $rawUsers = $stmt->fetchAll();

    $users = [];
    foreach ($rawUsers as $row) {
        $users[] = [
            'firstName'    => $row['first_name'],
            'lastName'     => $row['last_name'],
            'email'        => $row['email'],
            'accountType'  => $row['account_type'],
            'passwordHash' => $row['password_hash'],
            'salt'         => $row['salt'],
            'createdAt'    => $row['created_at'],
        ];
    }

    echo json_encode([
        'status' => 'success',
        'count' => count($users),
        'users' => $users
    ]);
} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode(['status' => 'error', 'message' => 'Database error: ' . $e->getMessage()]);
}
?>
