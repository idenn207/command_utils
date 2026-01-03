# server.ps1
# 설정: index.html이 있는 폴더 경로를 지정하세요
$webRoot = "C:\Users\사용자명\www"
$port = 3000

# HttpListener 생성 및 시작
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$port/")
$listener.Start()

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " 서버 실행 중: http://localhost:$port" -ForegroundColor Green
Write-Host " 웹 루트: $webRoot" -ForegroundColor Yellow
Write-Host " 종료: Ctrl+C" -ForegroundColor Gray
Write-Host "========================================" -ForegroundColor Cyan

try {
    while ($listener.IsListening) {
        # 요청 대기
        $context = $listener.GetContext()
        $request = $context.Request
        $response = $context.Response
        
        # 요청 경로 처리 (/ 이면 /index.html로)
        $path = $request.Url.LocalPath
        if ($path -eq "/") { $path = "/index.html" }
        
        # 실제 파일 경로
        $filePath = Join-Path $webRoot $path.TrimStart("/")
        
        # 로그 출력
        $time = Get-Date -Format "HH:mm:ss"
        Write-Host "[$time] $($request.HttpMethod) $path" -ForegroundColor White
        
        if (Test-Path $filePath) {
            # 파일 존재: 200 OK
            $content = [System.IO.File]::ReadAllBytes($filePath)
            $response.StatusCode = 200
            $response.ContentLength64 = $content.Length
            $response.OutputStream.Write($content, 0, $content.Length)
        }
        else {
            # 파일 없음: 404
            $message = "404 - File Not Found: $path"
            $content = [System.Text.Encoding]::UTF8.GetBytes($message)
            $response.StatusCode = 404
            $response.ContentLength64 = $content.Length
            $response.OutputStream.Write($content, 0, $content.Length)
            Write-Host "  -> 404 Not Found" -ForegroundColor Red
        }
        
        $response.Close()
    }
}
finally {
    $listener.Stop()
    Write-Host "서버 종료됨" -ForegroundColor Yellow
}
