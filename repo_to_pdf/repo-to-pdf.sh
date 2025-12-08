#!/bin/bash

#=============================================================================
# repo-to-pdf.sh
# 전체 레포지토리 소스코드를 하나의 PDF로 변환하는 스크립트
#
# 필수 패키지 설치:
#   Ubuntu/Debian: sudo apt install enscript ghostscript poppler-utils
#   macOS: brew install enscript ghostscript poppler
#   Fedora/RHEL: sudo dnf install enscript ghostscript poppler-utils
#=============================================================================

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 기본 설정
REPO_DIR="${1:-.}"
OUTPUT_FILE="${2:-repository_code.pdf}"
TEMP_DIR=$(mktemp -d)
EXTENSIONS="js,ts,jsx,tsx,py,java,c,cpp,h,hpp,cs,go,rs,rb,php,swift,kt,scala,html,css,scss,sass,less,json,xml,yaml,yml,md,txt,sh,bash,zsh,sql,r,lua,pl,pm,vue,svelte"

# 제외할 디렉토리
EXCLUDE_DIRS="node_modules|.git|.svn|vendor|dist|build|__pycache__|.idea|.vscode|coverage|.next|.nuxt"

# 함수: 사용법 출력
usage() {
    echo -e "${BLUE}사용법:${NC}"
    echo "  $0 [레포지토리_경로] [출력파일.pdf]"
    echo ""
    echo -e "${BLUE}예시:${NC}"
    echo "  $0                           # 현재 디렉토리 → repository_code.pdf"
    echo "  $0 ./my-project              # my-project 폴더 → repository_code.pdf"
    echo "  $0 ./my-project output.pdf   # my-project 폴더 → output.pdf"
    echo ""
    echo -e "${BLUE}지원 확장자:${NC}"
    echo "  $EXTENSIONS"
    exit 1
}

# 함수: 의존성 확인
check_dependencies() {
    local missing=()
    
    for cmd in enscript ps2pdf pdfunite; do
        if ! command -v $cmd &> /dev/null; then
            missing+=($cmd)
        fi
    done
    
    if [ ${#missing[@]} -ne 0 ]; then
        echo -e "${RED}오류: 다음 명령어가 설치되어 있지 않습니다: ${missing[*]}${NC}"
        echo ""
        echo -e "${YELLOW}설치 방법:${NC}"
        echo "  Ubuntu/Debian: sudo apt install enscript ghostscript poppler-utils"
        echo "  macOS:         brew install enscript ghostscript poppler"
        echo "  Fedora/RHEL:   sudo dnf install enscript ghostscript poppler-utils"
        exit 1
    fi
}

# 함수: 확장자로 enscript 언어 감지
get_language() {
    local ext="${1##*.}"
    case "$ext" in
        js|jsx|mjs)     echo "javascript" ;;
        ts|tsx)         echo "javascript" ;;
        py)             echo "python" ;;
        java)           echo "java" ;;
        c|h)            echo "c" ;;
        cpp|hpp|cc|cxx) echo "cpp" ;;
        cs)             echo "csharp" ;;
        go)             echo "go" ;;
        rb)             echo "ruby" ;;
        php)            echo "php" ;;
        sh|bash|zsh)    echo "bash" ;;
        sql)            echo "sql" ;;
        html|htm)       echo "html" ;;
        css|scss|sass)  echo "css" ;;
        xml)            echo "html" ;;
        *)              echo "" ;;
    esac
}

# 함수: 파일을 PDF로 변환
convert_to_pdf() {
    local file="$1"
    local output="$2"
    local lang=$(get_language "$file")
    local ps_file="${output%.pdf}.ps"
    
    # 상대 경로 계산
    local rel_path="${file#$REPO_DIR/}"
    
    # enscript 옵션
    local enscript_opts=(
        --line-numbers=1
        --font=Courier8
        --header="$rel_path|%W|Page \$% of \$="
        --word-wrap
        --mark-wrapped-lines=arrow
        --media=A4
        -o "$ps_file"
    )
    
    # 언어가 감지되면 구문 강조 추가
    if [ -n "$lang" ]; then
        enscript_opts+=(--highlight="$lang" --color=1)
    fi
    
    # 변환 실행
    if enscript "${enscript_opts[@]}" "$file" 2>/dev/null; then
        ps2pdf "$ps_file" "$output" 2>/dev/null
        rm -f "$ps_file"
        return 0
    else
        # enscript 실패 시 일반 텍스트로 시도
        enscript --line-numbers=1 --font=Courier8 --header="$rel_path|%W|Page \$% of \$=" -o "$ps_file" "$file" 2>/dev/null
        ps2pdf "$ps_file" "$output" 2>/dev/null
        rm -f "$ps_file"
        return 0
    fi
}

# 함수: 목차 페이지 생성
create_toc() {
    local toc_file="$TEMP_DIR/000_toc.txt"
    local toc_pdf="$TEMP_DIR/000_toc.pdf"
    
    echo "========================================" > "$toc_file"
    echo "        SOURCE CODE LISTING" >> "$toc_file"
    echo "========================================" >> "$toc_file"
    echo "" >> "$toc_file"
    echo "Repository: $(basename "$REPO_DIR")" >> "$toc_file"
    echo "Generated:  $(date '+%Y-%m-%d %H:%M:%S')" >> "$toc_file"
    echo "Total Files: $1" >> "$toc_file"
    echo "" >> "$toc_file"
    echo "----------------------------------------" >> "$toc_file"
    echo "TABLE OF CONTENTS" >> "$toc_file"
    echo "----------------------------------------" >> "$toc_file"
    echo "" >> "$toc_file"
    
    local idx=1
    while IFS= read -r file; do
        local rel_path="${file#$REPO_DIR/}"
        printf "%3d. %s\n" $idx "$rel_path" >> "$toc_file"
        ((idx++))
    done <<< "$2"
    
    echo "" >> "$toc_file"
    echo "========================================" >> "$toc_file"
    
    enscript --font=Courier10 --header="Table of Contents||" --media=A4 -o "${toc_pdf%.pdf}.ps" "$toc_file" 2>/dev/null
    ps2pdf "${toc_pdf%.pdf}.ps" "$toc_pdf"
    rm -f "${toc_pdf%.pdf}.ps"
}

# 메인 실행
main() {
    # 도움말 확인
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        usage
    fi
    
    # 의존성 확인
    check_dependencies
    
    # 레포지토리 디렉토리 확인
    if [ ! -d "$REPO_DIR" ]; then
        echo -e "${RED}오류: 디렉토리를 찾을 수 없습니다: $REPO_DIR${NC}"
        exit 1
    fi
    
    REPO_DIR=$(cd "$REPO_DIR" && pwd)
    
    echo -e "${BLUE}=== Repository to PDF Converter ===${NC}"
    echo -e "소스 디렉토리: ${GREEN}$REPO_DIR${NC}"
    echo -e "출력 파일: ${GREEN}$OUTPUT_FILE${NC}"
    echo ""
    
    # 확장자 패턴 생성
    local ext_pattern=$(echo "$EXTENSIONS" | sed 's/,/\\|/g')
    
    # 파일 목록 수집
    echo -e "${YELLOW}파일 검색 중...${NC}"
    local files=$(find "$REPO_DIR" -type f \
        | grep -Ev "($EXCLUDE_DIRS)" \
        | grep -E "\.($ext_pattern)$" \
        | sort)
    
    local file_count=$(echo "$files" | grep -c . || echo 0)
    
    if [ "$file_count" -eq 0 ]; then
        echo -e "${RED}오류: 변환할 소스 파일을 찾을 수 없습니다.${NC}"
        exit 1
    fi
    
    echo -e "발견된 파일: ${GREEN}${file_count}개${NC}"
    echo ""
    
    # 목차 생성
    echo -e "${YELLOW}목차 생성 중...${NC}"
    create_toc "$file_count" "$files"
    
    # 각 파일 변환
    echo -e "${YELLOW}파일 변환 중...${NC}"
    local idx=1
    local pdf_list=("$TEMP_DIR/000_toc.pdf")
    
    while IFS= read -r file; do
        local rel_path="${file#$REPO_DIR/}"
        local safe_name=$(echo "$rel_path" | sed 's/[\/:]/_/g')
        local pdf_file="$TEMP_DIR/$(printf '%04d' $idx)_${safe_name}.pdf"
        
        printf "\r  [%d/%d] %s" $idx $file_count "$rel_path"
        
        if convert_to_pdf "$file" "$pdf_file"; then
            pdf_list+=("$pdf_file")
        fi
        
        ((idx++))
    done <<< "$files"
    
    echo ""
    echo ""
    
    # PDF 병합
    echo -e "${YELLOW}PDF 병합 중...${NC}"
    if [ ${#pdf_list[@]} -gt 1 ]; then
        pdfunite "${pdf_list[@]}" "$OUTPUT_FILE"
        echo -e "${GREEN}완료!${NC}"
        echo ""
        echo -e "출력 파일: ${BLUE}$OUTPUT_FILE${NC}"
        echo -e "파일 크기: ${BLUE}$(du -h "$OUTPUT_FILE" | cut -f1)${NC}"
    else
        echo -e "${RED}오류: 병합할 PDF가 없습니다.${NC}"
        exit 1
    fi
    
    # 임시 파일 정리
    rm -rf "$TEMP_DIR"
}

main "$@"