@echo off
chcp 65001 >nul 2>&1
setlocal enabledelayedexpansion

REM ============================================================================
REM repo-to-pdf.bat
REM 전체 레포지토리 소스코드를 하나의 PDF로 변환하는 Windows 배치 스크립트
REM Python 및 필수 패키지 자동 설치 지원
REM ============================================================================

set "SCRIPT_DIR=%~dp0"
set "PYTHON_SCRIPT=%SCRIPT_DIR%repo_to_pdf.py"

REM 색상 (Windows 10 이상)
set "RED=[91m"
set "GREEN=[92m"
set "YELLOW=[93m"
set "BLUE=[94m"
set "CYAN=[96m"
set "NC=[0m"

echo.
echo %BLUE%╔════════════════════════════════════════════════╗%NC%
echo %BLUE%║   Repository to PDF Converter v2.0 (Windows)   ║%NC%
echo %BLUE%╚════════════════════════════════════════════════╝%NC%
echo.

REM ============================================================================
REM Python 확인 및 설치
REM ============================================================================

echo %CYAN%[1/4] Python 확인 중...%NC%

where python >nul 2>&1
if %errorlevel% neq 0 (
    echo %YELLOW%  Python이 설치되어 있지 않습니다.%NC%
    echo.
    
    REM winget으로 자동 설치 시도
    where winget >nul 2>&1
    if %errorlevel% equ 0 (
        set /p INSTALL_PYTHON="  winget으로 Python을 설치할까요? (Y/n): "
        if /i "!INSTALL_PYTHON!"=="" set "INSTALL_PYTHON=Y"
        if /i "!INSTALL_PYTHON!"=="Y" (
            echo %CYAN%  Python 설치 중... (몇 분 소요될 수 있습니다)%NC%
            winget install Python.Python.3.11 --silent --accept-package-agreements --accept-source-agreements
            
            REM PATH 갱신
            set "PATH=%PATH%;%LOCALAPPDATA%\Programs\Python\Python311;%LOCALAPPDATA%\Programs\Python\Python311\Scripts"
            
            REM 설치 확인
            where python >nul 2>&1
            if %errorlevel% neq 0 (
                echo %RED%  오류: Python 설치 후 PATH를 인식하지 못합니다.%NC%
                echo %YELLOW%  터미널을 다시 시작한 후 재실행하세요.%NC%
                pause
                exit /b 1
            )
            echo %GREEN%  Python 설치 완료!%NC%
        ) else (
            goto :manual_python_install
        )
    ) else (
        goto :manual_python_install
    )
) else (
    for /f "tokens=2" %%i in ('python --version 2^>^&1') do set PYTHON_VERSION=%%i
    echo %GREEN%  Python !PYTHON_VERSION! 발견%NC%
)

REM ============================================================================
REM pip 확인
REM ============================================================================

echo %CYAN%[2/4] pip 확인 중...%NC%

python -m pip --version >nul 2>&1
if %errorlevel% neq 0 (
    echo %YELLOW%  pip 설치 중...%NC%
    python -m ensurepip --upgrade >nul 2>&1
    if %errorlevel% neq 0 (
        curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
        python get-pip.py
        del get-pip.py
    )
)
echo %GREEN%  pip 확인 완료%NC%

REM ============================================================================
REM 필수 패키지 확인 및 설치
REM ============================================================================

echo %CYAN%[3/4] 필수 패키지 확인 중...%NC%

set "PACKAGES_TO_INSTALL="

REM pygments 확인
python -c "import pygments" 2>nul
if %errorlevel% neq 0 (
    set "PACKAGES_TO_INSTALL=!PACKAGES_TO_INSTALL! pygments"
)

REM reportlab 확인
python -c "import reportlab" 2>nul
if %errorlevel% neq 0 (
    set "PACKAGES_TO_INSTALL=!PACKAGES_TO_INSTALL! reportlab"
)

REM PyPDF2 확인
python -c "import PyPDF2" 2>nul
if %errorlevel% neq 0 (
    set "PACKAGES_TO_INSTALL=!PACKAGES_TO_INSTALL! PyPDF2"
)

if not "!PACKAGES_TO_INSTALL!"=="" (
    echo %YELLOW%  누락된 패키지:!PACKAGES_TO_INSTALL!%NC%
    echo.
    set /p INSTALL_PKGS="  패키지를 설치할까요? (Y/n): "
    if /i "!INSTALL_PKGS!"=="" set "INSTALL_PKGS=Y"
    if /i "!INSTALL_PKGS!"=="Y" (
        echo %CYAN%  패키지 설치 중...%NC%
        python -m pip install !PACKAGES_TO_INSTALL! --quiet --disable-pip-version-check
        if %errorlevel% neq 0 (
            echo %RED%  오류: 패키지 설치 실패%NC%
            echo   수동 설치: pip install!PACKAGES_TO_INSTALL!
            pause
            exit /b 1
        )
        echo %GREEN%  패키지 설치 완료!%NC%
    ) else (
        echo %RED%  설치가 취소되었습니다.%NC%
        pause
        exit /b 1
    )
) else (
    echo %GREEN%  모든 패키지가 설치되어 있습니다.%NC%
)

REM ============================================================================
REM Python 스크립트 확인
REM ============================================================================

echo %CYAN%[4/4] 스크립트 확인 중...%NC%

if not exist "%PYTHON_SCRIPT%" (
    echo %YELLOW%  repo_to_pdf.py 파일이 없습니다. 생성 중...%NC%
    
    REM 스크립트가 없으면 인라인으로 다운로드 또는 오류
    echo %RED%  오류: repo_to_pdf.py 파일을 찾을 수 없습니다.%NC%
    echo   이 배치 파일과 같은 폴더에 repo_to_pdf.py를 넣어주세요.
    echo   경로: %PYTHON_SCRIPT%
    pause
    exit /b 1
)
echo %GREEN%  스크립트 확인 완료%NC%

echo.

REM ============================================================================
REM 인자 처리 및 실행
REM ============================================================================

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
set "EXIT_CODE=%errorlevel%"

if %EXIT_CODE% equ 0 (
    echo.
    echo %GREEN%PDF 생성이 완료되었습니다!%NC%
    echo.
    
    REM PDF 파일 열기 여부
    set /p OPEN_PDF="PDF 파일을 열까요? (Y/n): "
    if /i "!OPEN_PDF!"=="" set "OPEN_PDF=Y"
    if /i "!OPEN_PDF!"=="Y" (
        start "" "%OUTPUT_FILE%"
    )
) else (
    echo.
    echo %RED%오류가 발생했습니다. (코드: %EXIT_CODE%)%NC%
)

echo.
pause
exit /b %EXIT_CODE%

REM ============================================================================
REM 수동 Python 설치 안내
REM ============================================================================

:manual_python_install
echo.
echo %RED%Python을 수동으로 설치해야 합니다.%NC%
echo.
echo %BLUE%설치 방법:%NC%
echo   1. https://www.python.org/downloads/ 방문
echo   2. "Download Python 3.x" 클릭하여 다운로드
echo   3. 설치 시 %YELLOW%"Add Python to PATH"%NC% 반드시 체크!
echo   4. 설치 완료 후 이 스크립트 다시 실행
echo.
echo %CYAN%또는 Microsoft Store에서 "Python 3.11" 검색하여 설치%NC%
echo.
pause
exit /b 1

REM ============================================================================
REM 도움말
REM ============================================================================

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
echo %BLUE%자동 설치 항목:%NC%
echo   - Python (winget 사용 가능 시)
echo   - pygments (구문 강조)
echo   - reportlab (PDF 생성)
echo   - PyPDF2 (PDF 병합)
echo.
echo %BLUE%지원 파일 형식:%NC%
echo   JavaScript, TypeScript, Python, Java, C/C++, C#, Go, Rust,
echo   Ruby, PHP, Swift, Kotlin, HTML, CSS, JSON, YAML, Markdown 등
echo.
pause
exit /b 0
