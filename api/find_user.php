<?php
require_once 'db_connect.php';

$email = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $raw = file_get_contents('php://input');
    $data = json_decode($raw, true);
    $email = strtolower(trim($data['email'] ?? ''));
} else {
    $email = strtolower(trim($_GET['email'] ?? ''));
}

if (empty($email)) {
    http_response_code(400);
    echo json_encode(['status' => 'error', 'message' => 'Email parameter is required.']);
    exit();
}

try {
    $stmt = $pdo->prepare("SELECT id, first_name, last_name, email, account_type, password_hash, salt, created_at FROM users WHERE email = ? LIMIT 1");
    $stmt->execute([$email]);
    $user = $stmt->fetch();

    if ($user) {
        echo json_encode([
            'status' => 'success',
            'user' => [
                'firstName'    => $user['first_name'],
                'lastName'     => $user['last_name'],
                'email'        => $user['email'],
                'accountType'  => $user['account_type'],
                'passwordHash' => $user['password_hash'],
                'salt'         => $user['salt'],
                'createdAt'    => $user['created_at'],
            ]
        ]);
    } else {
        http_response_code(404);
        echo json_encode(['status' => 'error', 'message' => 'User not found.']);
    }
} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode(['status' => 'error', 'message' => 'Database error: ' . $e->getMessage()]);
}
?>
