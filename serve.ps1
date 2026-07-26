$root = $PSScriptRoot
$port = 8123
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$port/")
$listener.Start()
Write-Host "Serving $root on http://localhost:$port/"

$mime = @{
  ".html" = "text/html; charset=utf-8"
  ".css"  = "text/css"
  ".js"   = "application/javascript"
  ".png"  = "image/png"
  ".jpg"  = "image/jpeg"
  ".jpeg" = "image/jpeg"
  ".svg"  = "image/svg+xml"
  ".ico"  = "image/x-icon"
}

while ($listener.IsListening) {
  $context = $listener.GetContext()
  try {
    $request = $context.Request
    $response = $context.Response
    $response.KeepAlive = $false
    $response.SendChunked = $false

    $localPath = $request.Url.LocalPath
    if ($localPath -eq "/") { $localPath = "/index.html" }
    $safePath = $localPath.TrimStart("/") -replace "/", "\"
    $filePath = Join-Path $root $safePath

    if (Test-Path $filePath -PathType Leaf) {
      $ext = [System.IO.Path]::GetExtension($filePath).ToLower()
      $contentType = $mime[$ext]
      if (-not $contentType) { $contentType = "application/octet-stream" }
      $bytes = [System.IO.File]::ReadAllBytes($filePath)
      $response.ContentType = $contentType
      $response.ContentLength64 = [int64]$bytes.Length
      $response.StatusCode = 200
      $response.OutputStream.Write($bytes, 0, $bytes.Length)
    } else {
      $msg = [System.Text.Encoding]::UTF8.GetBytes("404 Not Found: $localPath")
      $response.ContentType = "text/plain; charset=utf-8"
      $response.ContentLength64 = [int64]$msg.Length
      $response.StatusCode = 404
      $response.OutputStream.Write($msg, 0, $msg.Length)
    }
  } catch {
    Write-Host "Request error: $_"
  } finally {
    try { $context.Response.OutputStream.Close() } catch {}
    try { $context.Response.Close() } catch {}
  }
}
