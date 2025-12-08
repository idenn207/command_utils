#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
repo_to_pdf.py
전체 레포지토리 소스코드를 하나의 PDF로 변환하는 Python 스크립트
Windows, macOS, Linux 모두 지원 + 필수 패키지 자동 설치

사용법:
    python repo_to_pdf.py [레포지토리_경로] [출력파일.pdf]
"""

import os
import sys
import subprocess
import argparse
from pathlib import Path
from datetime import datetime
from typing import List, Tuple, Optional

# ============================================================================
# 자동 패키지 설치
# ============================================================================

REQUIRED_PACKAGES = {
    'pygments': 'pygments',
    'reportlab': 'reportlab',
    'PyPDF2': 'PyPDF2',
}

def check_and_install_packages():
    """필수 패키지 확인 및 자동 설치"""
    missing_packages = []
    
    for import_name, pip_name in REQUIRED_PACKAGES.items():
        try:
            __import__(import_name)
        except ImportError:
            missing_packages.append(pip_name)
    
    if not missing_packages:
        return True
    
    print("=" * 50)
    print("  필수 패키지 설치")
    print("=" * 50)
    print(f"누락된 패키지: {', '.join(missing_packages)}")
    print()
    
    # 자동 설치 시도
    try:
        # 사용자 확인 (터미널에서 실행 중인 경우)
        if sys.stdin.isatty():
            response = input("자동으로 설치할까요? (Y/n): ").strip().lower()
            if response and response != 'y':
                print("\n설치가 취소되었습니다.")
                print(f"수동 설치: pip install {' '.join(missing_packages)}")
                sys.exit(1)
        
        print("\n패키지 설치 중...")
        
        for package in missing_packages:
            print(f"  {package} 설치 중...")
            subprocess.check_call(
                [sys.executable, '-m', 'pip', 'install', package, '--quiet'],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL
            )
            print(f"  {package} ✓")
        
        print("\n패키지 설치 완료!")
        print()
        return True
        
    except subprocess.CalledProcessError as e:
        print(f"\n오류: 패키지 설치 실패")
        print(f"수동 설치를 시도하세요: pip install {' '.join(missing_packages)}")
        sys.exit(1)
    except Exception as e:
        print(f"\n오류: {e}")
        sys.exit(1)

# 패키지 설치 확인 (import 전에 실행)
check_and_install_packages()

# 이제 패키지 import
from pygments import highlight
from pygments.lexers import get_lexer_for_filename, get_lexer_by_name, TextLexer
from pygments.formatters import HtmlFormatter
from pygments.util import ClassNotFound

from reportlab.lib.pagesizes import A4
from reportlab.lib.units import mm
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.enums import TA_LEFT
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, PageBreak, Preformatted
from reportlab.lib import colors
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont

try:
    from PyPDF2 import PdfMerger
except ImportError:
    PdfMerger = None


# ============================================================================
# 설정
# ============================================================================

# 지원하는 소스코드 확장자
SOURCE_EXTENSIONS = {
    # 웹 개발
    '.js', '.jsx', '.ts', '.tsx', '.mjs', '.cjs',
    '.html', '.htm', '.css', '.scss', '.sass', '.less',
    '.vue', '.svelte',
    # 프로그래밍 언어
    '.py', '.pyw',
    '.java',
    '.c', '.h', '.cpp', '.hpp', '.cc', '.cxx', '.hxx',
    '.cs',
    '.go',
    '.rs',
    '.rb', '.erb',
    '.php',
    '.swift',
    '.kt', '.kts',
    '.scala',
    '.r', '.R',
    '.lua',
    '.pl', '.pm',
    '.sh', '.bash', '.zsh', '.fish',
    '.ps1', '.psm1',  # PowerShell
    '.bat', '.cmd',   # Batch
    # 데이터/설정
    '.json', '.xml', '.yaml', '.yml', '.toml',
    '.ini', '.cfg', '.conf',
    '.sql',
    '.graphql', '.gql',
    # 문서
    '.md', '.markdown', '.rst', '.txt',
    # 기타
    '.dockerfile', '.makefile',
}

# 제외할 디렉토리
EXCLUDE_DIRS = {
    'node_modules', '.git', '.svn', '.hg',
    'vendor', 'dist', 'build', 'out',
    '__pycache__', '.pytest_cache', '.mypy_cache',
    '.idea', '.vscode', '.vs',
    'coverage', '.nyc_output',
    '.next', '.nuxt', '.output',
    'target', 'bin', 'obj',
    'venv', 'env', '.env',
    'eggs', '*.egg-info',
}

# 제외할 파일 패턴
EXCLUDE_FILES = {
    'package-lock.json', 'yarn.lock', 'pnpm-lock.yaml',
    'Cargo.lock', 'poetry.lock', 'Pipfile.lock',
    '.DS_Store', 'Thumbs.db',
}


# ============================================================================
# 유틸리티 함수
# ============================================================================

def should_exclude_dir(dir_name: str) -> bool:
    """디렉토리를 제외해야 하는지 확인"""
    return dir_name in EXCLUDE_DIRS or dir_name.startswith('.')


def should_include_file(file_path: Path) -> bool:
    """파일을 포함해야 하는지 확인"""
    if file_path.name in EXCLUDE_FILES:
        return False
    if file_path.suffix.lower() in SOURCE_EXTENSIONS:
        return True
    if file_path.name.lower() in {'dockerfile', 'makefile', 'jenkinsfile', 'rakefile'}:
        return True
    return False


def get_all_source_files(repo_path: Path) -> List[Path]:
    """레포지토리에서 모든 소스 파일 찾기"""
    files = []
    
    for root, dirs, filenames in os.walk(repo_path):
        # 제외할 디렉토리 필터링
        dirs[:] = [d for d in dirs if not should_exclude_dir(d)]
        
        for filename in filenames:
            file_path = Path(root) / filename
            if should_include_file(file_path):
                files.append(file_path)
    
    return sorted(files)


def read_file_safely(file_path: Path) -> Tuple[str, str]:
    """파일을 안전하게 읽기 (인코딩 자동 감지)"""
    encodings = ['utf-8', 'utf-8-sig', 'cp949', 'euc-kr', 'latin-1']
    
    for encoding in encodings:
        try:
            with open(file_path, 'r', encoding=encoding) as f:
                return f.read(), encoding
        except (UnicodeDecodeError, UnicodeError):
            continue
    
    # 최후의 수단: 바이너리로 읽고 에러 무시
    with open(file_path, 'r', encoding='utf-8', errors='replace') as f:
        return f.read(), 'utf-8 (with errors)'


def get_lexer_for_file(file_path: Path):
    """파일에 맞는 pygments lexer 가져오기"""
    try:
        return get_lexer_for_filename(str(file_path))
    except ClassNotFound:
        # 특수 파일명 처리
        name_lower = file_path.name.lower()
        if name_lower == 'dockerfile':
            return get_lexer_by_name('docker')
        elif name_lower == 'makefile':
            return get_lexer_by_name('make')
        elif name_lower == 'jenkinsfile':
            return get_lexer_by_name('groovy')
        return TextLexer()


# ============================================================================
# PDF 생성
# ============================================================================

class PDFGenerator:
    """PDF 생성 클래스"""
    
    def __init__(self, output_path: str, repo_name: str):
        self.output_path = output_path
        self.repo_name = repo_name
        self.styles = getSampleStyleSheet()
        self._setup_styles()
    
    def _setup_styles(self):
        """스타일 설정"""
        # 코드 스타일
        self.styles.add(ParagraphStyle(
            name='Code',
            fontName='Courier',
            fontSize=8,
            leading=10,
            leftIndent=10,
            textColor=colors.black,
            backColor=colors.Color(0.97, 0.97, 0.97),
        ))
        
        # 파일 경로 스타일
        self.styles.add(ParagraphStyle(
            name='FilePath',
            fontName='Helvetica-Bold',
            fontSize=10,
            leading=14,
            textColor=colors.Color(0.2, 0.2, 0.6),
            spaceAfter=5,
        ))
        
        # 구분선 스타일
        self.styles.add(ParagraphStyle(
            name='Separator',
            fontName='Courier',
            fontSize=8,
            textColor=colors.grey,
        ))
    
    def create_toc_page(self, files: List[Path], repo_path: Path) -> List:
        """목차 페이지 생성"""
        elements = []
        
        # 제목
        title_style = ParagraphStyle(
            name='Title',
            fontName='Helvetica-Bold',
            fontSize=18,
            alignment=1,  # CENTER
            spaceAfter=20,
        )
        elements.append(Paragraph("SOURCE CODE LISTING", title_style))
        elements.append(Spacer(1, 10))
        
        # 메타 정보
        meta_style = self.styles['Normal']
        elements.append(Paragraph(f"<b>Repository:</b> {self.repo_name}", meta_style))
        elements.append(Paragraph(f"<b>Generated:</b> {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}", meta_style))
        elements.append(Paragraph(f"<b>Total Files:</b> {len(files)}", meta_style))
        elements.append(Spacer(1, 20))
        
        # 구분선
        elements.append(Paragraph("─" * 60, self.styles['Separator']))
        elements.append(Paragraph("<b>TABLE OF CONTENTS</b>", meta_style))
        elements.append(Paragraph("─" * 60, self.styles['Separator']))
        elements.append(Spacer(1, 10))
        
        # 파일 목록
        toc_style = ParagraphStyle(
            name='TOC',
            fontName='Courier',
            fontSize=8,
            leading=11,
        )
        
        for idx, file_path in enumerate(files, 1):
            rel_path = file_path.relative_to(repo_path)
            elements.append(Paragraph(f"{idx:4d}. {rel_path}", toc_style))
        
        elements.append(PageBreak())
        return elements
    
    def create_file_section(self, file_path: Path, repo_path: Path, index: int) -> List:
        """파일 섹션 생성"""
        elements = []
        
        # 파일 경로 헤더
        rel_path = file_path.relative_to(repo_path)
        elements.append(Paragraph("─" * 70, self.styles['Separator']))
        elements.append(Paragraph(f"[{index}] {rel_path}", self.styles['FilePath']))
        elements.append(Paragraph("─" * 70, self.styles['Separator']))
        elements.append(Spacer(1, 5))
        
        # 파일 내용 읽기
        content, _ = read_file_safely(file_path)
        
        # 내용이 너무 길면 truncate
        max_lines = 2000
        lines = content.split('\n')
        if len(lines) > max_lines:
            content = '\n'.join(lines[:max_lines])
            content += f"\n\n... (truncated, {len(lines) - max_lines} more lines)"
        
        # 특수 문자 이스케이프
        content = content.replace('&', '&amp;')
        content = content.replace('<', '&lt;')
        content = content.replace('>', '&gt;')
        
        # 라인 번호 추가
        numbered_lines = []
        for i, line in enumerate(content.split('\n'), 1):
            # 빈 줄 처리
            if not line:
                line = ' '
            numbered_lines.append(f"{i:4d} │ {line}")
        
        content_with_numbers = '\n'.join(numbered_lines)
        
        # 코드 블록
        code_style = ParagraphStyle(
            name='CodeBlock',
            fontName='Courier',
            fontSize=7,
            leading=9,
            leftIndent=5,
            rightIndent=5,
        )
        
        # Preformatted 사용하여 공백 유지
        elements.append(Preformatted(content_with_numbers, code_style))
        elements.append(Spacer(1, 10))
        elements.append(PageBreak())
        
        return elements
    
    def generate(self, files: List[Path], repo_path: Path, progress_callback=None):
        """PDF 생성"""
        doc = SimpleDocTemplate(
            self.output_path,
            pagesize=A4,
            leftMargin=15*mm,
            rightMargin=15*mm,
            topMargin=15*mm,
            bottomMargin=15*mm,
        )
        
        elements = []
        
        # 목차 생성
        elements.extend(self.create_toc_page(files, repo_path))
        
        # 각 파일 섹션 생성
        total = len(files)
        for idx, file_path in enumerate(files, 1):
            if progress_callback:
                progress_callback(idx, total, file_path)
            
            try:
                elements.extend(self.create_file_section(file_path, repo_path, idx))
            except Exception as e:
                # 오류 발생 시 오류 메시지만 추가
                elements.append(Paragraph(f"Error reading file: {e}", self.styles['Normal']))
                elements.append(PageBreak())
        
        # PDF 빌드
        doc.build(elements)


# ============================================================================
# 메인
# ============================================================================

def print_progress(current: int, total: int, file_path: Path):
    """진행 상황 출력"""
    bar_length = 30
    progress = current / total
    filled = int(bar_length * progress)
    bar = '█' * filled + '░' * (bar_length - filled)
    
    # 파일명 truncate
    name = str(file_path.name)
    if len(name) > 30:
        name = name[:27] + '...'
    
    print(f"\r  [{bar}] {current}/{total} {name:<30}", end='', flush=True)


def main():
    parser = argparse.ArgumentParser(
        description='레포지토리 소스코드를 PDF로 변환',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
예시:
  python repo_to_pdf.py                         # 현재 디렉토리
  python repo_to_pdf.py ./my-project            # 특정 폴더
  python repo_to_pdf.py ./my-project output.pdf # 출력 파일 지정
        """
    )
    parser.add_argument('repo_path', nargs='?', default='.', help='레포지토리 경로 (기본값: 현재 디렉토리)')
    parser.add_argument('output', nargs='?', default='repository_code.pdf', help='출력 PDF 파일 (기본값: repository_code.pdf)')
    
    args = parser.parse_args()
    
    repo_path = Path(args.repo_path).resolve()
    output_path = args.output
    
    # 경로 확인
    if not repo_path.exists():
        print(f"오류: 경로를 찾을 수 없습니다: {repo_path}")
        sys.exit(1)
    
    if not repo_path.is_dir():
        print(f"오류: 디렉토리가 아닙니다: {repo_path}")
        sys.exit(1)
    
    print("╔" + "═" * 48 + "╗")
    print("║   Repository to PDF Converter v2.0            ║")
    print("╚" + "═" * 48 + "╝")
    print(f"소스 디렉토리: {repo_path}")
    print(f"출력 파일: {output_path}")
    print()
    
    # 파일 검색
    print("파일 검색 중...")
    files = get_all_source_files(repo_path)
    
    if not files:
        print("오류: 변환할 소스 파일을 찾을 수 없습니다.")
        sys.exit(1)
    
    print(f"  발견된 파일: {len(files)}개")
    print()
    
    # PDF 생성
    print("PDF 생성 중...")
    generator = PDFGenerator(output_path, repo_path.name)
    generator.generate(files, repo_path, progress_callback=print_progress)
    
    print()
    print()
    print("╔" + "═" * 48 + "╗")
    print("║              변환 완료!                        ║")
    print("╚" + "═" * 48 + "╝")
    print(f"  출력 파일: {output_path}")
    
    # 파일 크기 표시
    output_size = Path(output_path).stat().st_size
    if output_size > 1024 * 1024:
        size_str = f"{output_size / (1024*1024):.1f} MB"
    else:
        size_str = f"{output_size / 1024:.1f} KB"
    print(f"  파일 크기: {size_str}")
    print(f"  총 파일 수: {len(files)}개")


if __name__ == '__main__':
    main()
