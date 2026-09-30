<?php
require_once 'db_connect.php';

$raw = file_get_contents('php://input');
$data = json_decode($raw, true);

if (!$data) {
    http_response_code(400);
    echo json_encode(['status' => 'error', 'message' => 'Invalid JSON input']);
    exit();
}

$firstName    = trim($data['firstName'] ?? '');
$lastName     = trim($data['lastName'] ?? '');
$email        = strtolower(trim($data['email'] ?? ''));
$accountType  = trim($data['accountType'] ?? 'Doctor');
$passwordHash = trim($data['passwordHash'] ?? '');
$salt         = trim($data['salt'] ?? '');
$createdAt    = trim($data['createdAt'] ?? date('Y-m-d H:i:s'));

if (empty($firstName) || empty($lastName) || empty($email) || empty($passwordHash)) {
    http_response_code(400);
    echo json_encode(['status' => 'error', 'message' => 'All fields are required.']);
    exit();
}

try {
    // Check if user already exists
    $stmt = $pdo->prepare("SELECT id FROM users WHERE email = ? LIMIT 1");
    $stmt->execute([$email]);
    if ($stmt->fetch()) {
        http_response_code(409);
        echo json_encode(['status' => 'error', 'message' => 'An account with this email already exists.']);
        exit();
    }

    // Insert new user
    $insertStmt = $pdo->prepare("
        INSERT INTO users (first_name, last_name, email, account_type, password_hash, salt, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    ");
    $insertStmt->execute([
        $firstName,
        $lastName,
        $email,
        $accountType,
        $passwordHash,
        $salt,
        $createdAt
    ]);

    echo json_encode([
        'status' => 'success',
        'message' => 'User registered successfully in MySQL.',
        'userId' => $pdo->lastInsertId()
    ]);
} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode(['status' => 'error', 'message' => 'Database error: ' . $e->getMessage()]);
}
?>
