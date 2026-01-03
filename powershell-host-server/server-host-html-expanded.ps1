# server-host-html-expanded.ps1
# ============================================
# 설정
# ============================================
$webRoot = "C:\Users\사용자명\www"  # 실제 경로로 변경
$port = 3000

# ============================================
# MIME 타입 정의
# ============================================
$mimeTypes = @{
    ".html" = "text/html; charset=utf-8"
    ".htm"  = "text/html; charset=utf-8"
    ".css"  = "text/css; charset=utf-8"
    ".js"   = "application/javascript; charset=utf-8"
    ".json" = "application/json; charset=utf-8"
    ".png"  = "image/png"
    ".jpg"  = "image/jpeg"
    ".jpeg" = "image/jpeg"
    ".gif"  = "image/gif"
    ".svg"  = "image/svg+xml"
    ".ico"  = "image/x-icon"
    ".woff" = "font/woff"
    ".woff2"= "font/woff2"
    ".ttf"  = "font/ttf"
    ".mp3"  = "audio/mpeg"
    ".mp4"  = "video/mp4"
    ".webp" = "image/webp"
    ".txt"  = "text/plain; charset=utf-8"
}

# ============================================
# 로컬 IP 주소 가져오기
# ============================================
$localIP = (Get-NetIPAddress -AddressFamily IPv4 | 
    Where-Object { $_.InterfaceAlias -notlike "*Loopback*" -and $_.IPAddress -notlike "169.*" } | 
    Select-Object -First 1).IPAddress

if (-not $localIP) { $localIP = "IP를 찾을 수 없음" }

# ============================================
# HttpListener 생성
# ============================================
$listener = New-Object System.Net.HttpListener

# localhost와 LAN IP 모두 허용
$listener.Prefixes.Add("http://localhost:$port/")
$listener.Prefixes.Add("http://$($localIP):$port/")
$listener.Prefixes.Add("http://+:$port/")  # 모든 IP (관리자 권한 필요)

try {
    $listener.Start()
}
catch {
    # 권한 없으면 localhost만으로 재시도
    Write-Host "관리자 권한 없음 - localhost 전용 모드" -ForegroundColor Yellow
    $listener = New-Object System.Net.HttpListener
    $listener.Prefixes.Add("http://localhost:$port/")
    $listener.Start()
    $localIP = "localhost 전용"
}

# ============================================
# 시작 메시지
# ============================================
Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " PowerShell 웹 서버 v1.0" -ForegroundColor White
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " 로컬 접속:  http://localhost:$port" -ForegroundColor Green
Write-Host " LAN 접속:   http://$($localIP):$port" -ForegroundColor Green
Write-Host " 웹 루트:    $webRoot" -ForegroundColor Yellow
Write-Host " 종료:       Ctrl+C" -ForegroundColor Gray
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# ============================================
# 요청 처리 루프
# ============================================
try {
    while ($listener.IsListening) {
        $context = $listener.GetContext()
        $request = $context.Request
        $response = $context.Response
        
        # 경로 처리
        $path = $request.Url.LocalPath
        if ($path -eq "/") { $path = "/index.html" }
        
        # 보안: 상위 디렉토리 접근 차단
        if ($path -match "\.\.") {
            $response.StatusCode = 403
            $response.Close()
            continue
        }
        
        # 파일 경로 생성
        $filePath = Join-Path $webRoot $path.TrimStart("/")
        
        # 로그
        $time = Get-Date -Format "HH:mm:ss"
        $clientIP = $request.RemoteEndPoint.Address
        
        if (Test-Path $filePath) {
            # 파일 존재
            $extension = [System.IO.Path]::GetExtension($filePath).ToLower()
            $contentType = $mimeTypes[$extension]
            if (-not $contentType) { $contentType = "application/octet-stream" }
            
            $content = [System.IO.File]::ReadAllBytes($filePath)
            
            $response.StatusCode = 200
            $response.ContentType = $contentType
            $response.ContentLength64 = $content.Length
            $response.OutputStream.Write($content, 0, $content.Length)
            
            Write-Host "[$time] $clientIP -> $path (200 OK)" -ForegroundColor Green
        }
        else {
            # 404
            $html = @"
<!DOCTYPE html>
<html>
<head><meta charset="UTF-8"><title>404</title></head>
<body style="font-family:sans-serif;text-align:center;padding:50px;">
<h1>404 - Not Found</h1>
<p>요청한 파일을 찾을 수 없습니다: $path</p>
</body>
</html>
"@
            $content = [System.Text.Encoding]::UTF8.GetBytes($html)
            
            $response.StatusCode = 404
            $response.ContentType = "text/html; charset=utf-8"
            $response.ContentLength64 = $content.Length
            $response.OutputStream.Write($content, 0, $content.Length)
            
            Write-Host "[$time] $clientIP -> $path (404 Not Found)" -ForegroundColor Red
        }
        
        $response.Close()
    }
}
finally {
    $listener.Stop()
    Write-Host ""
    Write-Host "서버가 종료되었습니다." -ForegroundColor Yellow
}
