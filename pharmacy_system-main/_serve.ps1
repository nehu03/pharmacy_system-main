$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$port = 8765
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://127.0.0.1:$port/")
try {
  $listener.Start()
} catch {
  Write-Host "Could not bind port ${port}: $_"
  exit 1
}
$rootFull = [IO.Path]::GetFullPath($root)
Write-Host "Pharmacy UI: http://127.0.0.1:$port/login.html"
Write-Host "Press Ctrl+C to stop."
Start-Process "http://127.0.0.1:$port/login.html"
while ($listener.IsListening) {
  try {
    $ctx = $listener.GetContext()
    $req = $ctx.Request
    $res = $ctx.Response
    $rel = [Uri]::UnescapeDataString(($req.Url.LocalPath -replace '^/', ''))
    if ([string]::IsNullOrEmpty($rel)) { $rel = 'login.html' }
    $full = [IO.Path]::GetFullPath((Join-Path $root $rel))
    if (-not $full.StartsWith($rootFull, [StringComparison]::OrdinalIgnoreCase)) {
      $res.StatusCode = 403
      $res.Close()
      continue
    }
    if (-not (Test-Path $full -PathType Leaf)) {
      $res.StatusCode = 404
      $notFound = [Text.Encoding]::UTF8.GetBytes('404 Not Found')
      $res.ContentLength64 = $notFound.Length
      $res.OutputStream.Write($notFound, 0, $notFound.Length)
      $res.Close()
      continue
    }
    $bytes = [IO.File]::ReadAllBytes($full)
    $ext = [IO.Path]::GetExtension($full).ToLowerInvariant()
    $res.ContentType = switch ($ext) {
      '.html' { 'text/html; charset=utf-8' }
      '.css' { 'text/css; charset=utf-8' }
      '.js' { 'application/javascript; charset=utf-8' }
      '.json' { 'application/json; charset=utf-8' }
      '.png' { 'image/png' }
      '.jpg' { 'image/jpeg' }
      '.jpeg' { 'image/jpeg' }
      '.gif' { 'image/gif' }
      '.svg' { 'image/svg+xml' }
      '.ico' { 'image/x-icon' }
      '.woff' { 'font/woff' }
      '.woff2' { 'font/woff2' }
      default { 'application/octet-stream' }
    }
    $res.ContentLength64 = $bytes.Length
    $res.OutputStream.Write($bytes, 0, $bytes.Length)
    $res.Close()
  } catch {
    if (-not $listener.IsListening) { break }
  }
}
