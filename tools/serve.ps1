# 이 폴더를 http://localhost:8000 으로 보여 주는 간이 서버 (Python이 없을 때 사용)
# 실행: powershell -ExecutionPolicy Bypass -File tools\serve.ps1     끝내기: Ctrl+C
param([int]$Port = 8000)
$root = Split-Path -Parent $PSScriptRoot
$types = @{ '.html'='text/html; charset=utf-8'; '.json'='application/json; charset=utf-8'; '.js'='text/javascript; charset=utf-8'; '.css'='text/css; charset=utf-8'; '.md'='text/plain; charset=utf-8'; '.png'='image/png'; '.pdf'='application/pdf'; '.svg'='image/svg+xml' }
$l = New-Object System.Net.HttpListener
$l.Prefixes.Add("http://localhost:$Port/")
$l.Start()
"http://localhost:$Port 에서 보여 주는 중 (끝내려면 Ctrl+C)"
try {
  while($l.IsListening){
    $c = $l.GetContext()
    try {
      $path = [Uri]::UnescapeDataString($c.Request.Url.AbsolutePath.TrimStart('/'))
      if(-not $path){ $path = 'index.html' }
      $file = [IO.Path]::GetFullPath((Join-Path $root $path))
      if($file.StartsWith($root) -and (Test-Path $file -PathType Leaf)){
        $bytes = [IO.File]::ReadAllBytes($file)
        $ct = $types[[IO.Path]::GetExtension($file).ToLower()]
        $c.Response.ContentType = $(if($ct){ $ct } else { 'application/octet-stream' })
        $c.Response.ContentLength64 = $bytes.Length
        if($c.Request.HttpMethod -ne 'HEAD'){ $c.Response.OutputStream.Write($bytes, 0, $bytes.Length) }
      } else { $c.Response.StatusCode = 404 }
    } catch { "요청 처리 실패: $($_.Exception.Message)" }
    finally { try { $c.Response.Close() } catch {} }
  }
} finally { $l.Stop() }
