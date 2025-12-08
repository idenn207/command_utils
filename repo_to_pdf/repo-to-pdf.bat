@echo off
chcp 65001 >nul 2>&1
setlocal enabledelayedexpansion

REM ============================================================================
REM repo-to-pdf.bat
REM 전체 레포지토리 소스코드를 하나의 PDF로 변환하는 Windows 배치 스크립트
REM
REM 필수 요구사항:
REM   - Python 3.7 이상
REM   - pip install pygments reportlab PyPDF2
REM ============================================================================

set "SCRIPT_DIR=%~dp0"
set "PYTHON_SCRIPT=%SCRIPT_DIR%repo_to_pdf.py"

REM 색상은 Windows 10 이상에서만 지원
set "RED=[91m"
set "GREEN=[92m"
set "YELLOW=[93m"
set "BLUE=[94m"
set "NC=[0m"

echo.
echo %BLUE%============================================%NC%
echo %BLUE%  Repository to PDF Converter (Windows)%NC%
echo %BLUE%============================================%NC%
echo.

REM Python 확인
where python >nul 2>&1
if %errorlevel% neq 0 (
    echo %RED%오류: Python이 설치되어 있지 않습니다.%NC%
    echo.
    echo Python 설치 방법:
    echo   1. https://www.python.org/downloads/ 에서 다운로드
    echo   2. 설치 시 "Add Python to PATH" 체크
    echo.
    pause
    exit /b 1
)

REM Python 버전 확인
for /f "tokens=2" %%i in ('python --version 2^>^&1') do set PYTHON_VERSION=%%i
echo Python 버전: %PYTHON_VERSION%

REM 필수 패키지 확인
echo.
echo 필수 패키지 확인 중...

python -c "import pygments" 2>nul
if %errorlevel% neq 0 (
    echo %YELLOW%pygments 설치 중...%NC%
    pip install pygments --quiet
)

python -c "import reportlab" 2>nul
if %errorlevel% neq 0 (
    echo %YELLOW%reportlab 설치 중...%NC%
    pip install reportlab --quiet
)

python -c "import PyPDF2" 2>nul
if %errorlevel% neq 0 (
    echo %YELLOW%PyPDF2 설치 중...%NC%
    pip install PyPDF2 --quiet
)

echo %GREEN%패키지 확인 완료%NC%
echo.

REM Python 스크립트 존재 확인
if not exist "%PYTHON_SCRIPT%" (
    echo %RED%오류: repo_to_pdf.py 파일을 찾을 수 없습니다.%NC%
    echo 경로: %PYTHON_SCRIPT%
    echo.
    echo repo_to_pdf.py 파일을 이 배치 파일과 같은 폴더에 두세요.
    pause
    exit /b 1
)

REM 인자 처리
set "REPO_PATH=%~1"
set "OUTPUT_FILE=%~2"

if "%REPO_PATH%"=="" set "REPO_PATH=."
if "%OUTPUT_FILE%"=="" set "OUTPUT_FILE=repository_code.pdf"

REM 도움말
if "%REPO_PATH%"=="-h" goto :help
if "%REPO_PATH%"=="--help" goto :help
if "%REPO_PATH%"=="/?" goto :help

REM Python 스크립트 실행
python "%PYTHON_SCRIPT%" "%REPO_PATH%" "%OUTPUT_FILE%"

if %errorlevel% equ 0 (
    echo.
    echo %GREEN%PDF 생성이 완료되었습니다!%NC%
    
    REM PDF 자동 열기 (선택사항)
    set /p OPEN_PDF="PDF 파일을 열까요? (Y/N): "
    if /i "!OPEN_PDF!"=="Y" (
        start "" "%OUTPUT_FILE%"
    )
) else (
    echo.
    echo %RED%오류가 발생했습니다.%NC%
)

echo.
pause
exit /b %errorlevel%

:help
echo.
echo %BLUE%사용법:%NC%
echo   %~nx0 [레포지토리_경로] [출력파일.pdf]
echo.
echo %BLUE%예시:%NC%
echo   %~nx0                           # 현재 폴더 → repository_code.pdf
echo   %~nx0 .\my-project              # my-project 폴더 → repository_code.pdf
echo   %~nx0 .\my-project output.pdf   # my-project 폴더 → output.pdf
echo   %~nx0 C:\Users\me\project       # 절대 경로도 가능
echo.
echo %BLUE%지원 파일 형식:%NC%
echo   JavaScript, TypeScript, Python, Java, C/C++, C#, Go, Rust,
echo   Ruby, PHP, Swift, Kotlin, HTML, CSS, JSON, YAML, Markdown 등
echo.
pause
exit /b 0
