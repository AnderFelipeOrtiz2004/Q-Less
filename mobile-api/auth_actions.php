<?php

function perform_password_reset(mysqli $conn, string $email, string $code, string $newPassword): array
{
    $email = strtolower(trim($email));
    $code = trim($code);

    if (!filter_var($email, FILTER_VALIDATE_EMAIL) || !is_gmail_email($email) || $code === '') {
        return ['ok' => false, 'message' => 'Correo Gmail y código son requeridos'];
    }
    if (strlen($newPassword) < 6) {
        return ['ok' => false, 'message' => 'La contraseña debe tener al menos 6 caracteres'];
    }

    $stmt = $conn->prepare(
        "SELECT id, code_hash FROM password_reset_codes
         WHERE email = ? AND used_at IS NULL AND expires_at > NOW()
         ORDER BY id DESC LIMIT 1"
    );
    $stmt->bind_param('s', $email);
    $stmt->execute();
    $resetRow = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    if (!$resetRow || !password_verify($code, $resetRow['code_hash'])) {
        return ['ok' => false, 'message' => 'Código inválido o expirado'];
    }

    $userStmt = $conn->prepare('SELECT id FROM users WHERE LOWER(email) = LOWER(?) LIMIT 1');
    $userStmt->bind_param('s', $email);
    $userStmt->execute();
    $user = $userStmt->get_result()->fetch_assoc();
    $userStmt->close();

    if (!$user) {
        return ['ok' => false, 'message' => 'Usuario no encontrado'];
    }

    $passwordHash = password_hash($newPassword, PASSWORD_BCRYPT);
    $upd = $conn->prepare('UPDATE users SET password = ? WHERE id = ?');
    $userId = (int) $user['id'];
    $upd->bind_param('si', $passwordHash, $userId);
    $upd->execute();
    $upd->close();

    $mark = $conn->prepare('UPDATE password_reset_codes SET used_at = NOW() WHERE id = ?');
    $resetId = (int) $resetRow['id'];
    $mark->bind_param('i', $resetId);
    $mark->execute();
    $mark->close();

    return ['ok' => true, 'message' => 'Contraseña actualizada. Ya puedes iniciar sesión.'];
}

function perform_email_verification(mysqli $conn, string $email, string $code): array
{
    $conn->query(
        "CREATE TABLE IF NOT EXISTS email_verification_codes (
            id INT PRIMARY KEY AUTO_INCREMENT,
            email VARCHAR(150) NOT NULL,
            code_hash VARCHAR(255) NOT NULL,
            payload_json TEXT NULL,
            expires_at DATETIME NOT NULL,
            used_at DATETIME NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX idx_email_verification_email (email)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci"
    );

    $email = strtolower(trim($email));
    $code = trim($code);

    if (!is_gmail_email($email) || $code === '') {
        return ['ok' => false, 'message' => 'Correo Gmail y código requeridos'];
    }

    $stmt = $conn->prepare(
        "SELECT id, code_hash FROM email_verification_codes
         WHERE email = ? AND used_at IS NULL AND expires_at > NOW()
         ORDER BY id DESC LIMIT 1"
    );
    $stmt->bind_param('s', $email);
    $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    if (!$row || !password_verify($code, $row['code_hash'])) {
        return ['ok' => false, 'message' => 'Código inválido o expirado'];
    }

    $upd = $conn->prepare('UPDATE users SET email_verified = 1, purchases_enabled = 1 WHERE LOWER(email) = LOWER(?)');
    $upd->bind_param('s', $email);
    $upd->execute();
    $upd->close();

    $mark = $conn->prepare('UPDATE email_verification_codes SET used_at = NOW() WHERE id = ?');
    $rowId = (int) $row['id'];
    $mark->bind_param('i', $rowId);
    $mark->execute();
    $mark->close();

    return ['ok' => true, 'message' => 'Correo Gmail verificado. Ya puedes iniciar sesión.'];
}
