<?php
header('Content-Type: application/json; charset=utf-8');

// Only POST
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['ok' => false, 'error' => 'Method not allowed']);
    exit;
}

// Rate limiting (simple, per IP, 5 submissions per hour)
$ip = $_SERVER['REMOTE_ADDR'] ?? 'unknown';
$rateFile = __DIR__ . '/data/.ratelimit';
$rates = [];
if (file_exists($rateFile)) {
    $rates = json_decode(file_get_contents($rateFile), true) ?: [];
}
$now = time();
// Clean old entries
foreach ($rates as $k => $entries) {
    $rates[$k] = array_filter($entries, fn($t) => $now - $t < 3600);
    if (empty($rates[$k])) unset($rates[$k]);
}
if (isset($rates[$ip]) && count($rates[$ip]) >= 5) {
    echo json_encode(['ok' => false, 'error' => 'Слишком много запросов. Попробуй позже.']);
    exit;
}
$rates[$ip][] = $now;
file_put_contents($rateFile, json_encode($rates));

// Sanitize input
$name = trim($_POST['name'] ?? '');
$email = trim($_POST['email'] ?? '');
$phone = trim($_POST['phone'] ?? '');
$problems = trim($_POST['problems'] ?? '');
$problemText = trim($_POST['problem_text'] ?? '');

// Validate
if ($name === '') {
    echo json_encode(['ok' => false, 'error' => 'Укажи своё имя.']);
    exit;
}
if ($email === '' && $phone === '') {
    echo json_encode(['ok' => false, 'error' => 'Укажи хотя бы email или телефон.']);
    exit;
}
if ($email !== '' && !filter_var($email, FILTER_VALIDATE_EMAIL)) {
    echo json_encode(['ok' => false, 'error' => 'Проверь правильность email.']);
    exit;
}

// Save
$entry = [
    'id' => uniqid(),
    'ts' => date('Y-m-d H:i:s'),
    'name' => mb_substr($name, 0, 100),
    'email' => mb_substr($email, 0, 200),
    'phone' => mb_substr($phone, 0, 30),
    'problems' => mb_substr($problems, 0, 500),
    'problem_text' => mb_substr($problemText, 0, 1000),
    'ip' => $ip,
];

$dataFile = __DIR__ . '/data/waitlist.json';
$data = [];
if (file_exists($dataFile)) {
    $data = json_decode(file_get_contents($dataFile), true) ?: [];
}

// Check duplicate by email or phone
foreach ($data as $existing) {
    if ($email !== '' && $existing['email'] === $email) {
        echo json_encode(['ok' => false, 'error' => 'Этот email уже в списке!']);
        exit;
    }
    if ($phone !== '' && $existing['phone'] === $phone && $phone !== '') {
        echo json_encode(['ok' => false, 'error' => 'Этот телефон уже в списке!']);
        exit;
    }
}

$data[] = $entry;
file_put_contents($dataFile, json_encode($data, JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT));

echo json_encode(['ok' => true]);
