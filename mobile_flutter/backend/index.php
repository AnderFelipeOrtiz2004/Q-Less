<?php
// Redirige cualquier petición de /backend/... a la raíz /...
$uri = $_SERVER['REQUEST_URI'];
$newUri = str_replace('/backend/', '/', $uri);
header("Location: " . $newUri, true, 301);
exit;
?>