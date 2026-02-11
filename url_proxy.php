<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/xml; charset=UTF-8");

$url = $_GET['url'];

if (!filter_var($url, FILTER_VALIDATE_URL)) {
    http_response_code(400);
    exit("Invalid URL");
}

$content = file_get_contents($url);
echo mb_convert_encoding($content, 'UTF-8', mb_detect_encoding($content, 'UTF-8, ISO-8859-1, ISO-8859-15', true));
