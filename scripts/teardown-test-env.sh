#!/bin/bash

# c4ang-quality-gate 테스트 환경 정리 스크립트
# K3d 클러스터 중지 또는 삭제

set -euo pipefail

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 설정 변수
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
INFRA_DIR="${PROJECT_ROOT}/c4ang-infra"
K3D_SCRIPT_DIR="${INFRA_DIR}/k8s-dev-k3d"
CLUSTER_NAME="${CLUSTER_NAME:-msa-quality-cluster}"

# 로그 함수
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# 환경 중지 (클러스터는 유지)
stop_environment() {
    log_step "테스트 환경 중지 중..."

    if [ -f "${K3D_SCRIPT_DIR}/scripts/stop-environment.sh" ]; then
        cd "${K3D_SCRIPT_DIR}/scripts"
        bash stop-environment.sh
        log_info "환경 중지 완료"
    else
        log_warn "환경 중지 스크립트를 찾을 수 없습니다."
        log_info "수동으로 클러스터를 중지하세요: k3d cluster stop ${CLUSTER_NAME}"
    fi
}

# 클러스터 완전 삭제
delete_cluster() {
    log_step "K3d 클러스터 삭제 중..."

    if ! command -v k3d &> /dev/null; then
        log_error "k3d가 설치되어 있지 않습니다."
        exit 1
    fi

    # 클러스터 존재 확인
    if k3d cluster list | grep -q "^${CLUSTER_NAME}"; then
        log_info "클러스터 '${CLUSTER_NAME}' 삭제 중..."
        k3d cluster delete "${CLUSTER_NAME}" || {
            log_error "클러스터 삭제 실패"
            exit 1
        }
        log_info "클러스터 삭제 완료"
    else
        log_warn "클러스터 '${CLUSTER_NAME}'를 찾을 수 없습니다."
    fi

    # 잔여 Docker 컨테이너 정리
    log_info "잔여 Docker 컨테이너 확인 중..."
    local remaining_containers
    remaining_containers=$(docker ps -a --format '{{.Names}}' | grep -E "k3d-${CLUSTER_NAME}-.*" || true)

    if [ -n "$remaining_containers" ]; then
        log_warn "잔여 컨테이너 발견, 정리 중..."
        echo "$remaining_containers" | while read -r container; do
            [ -n "$container" ] && docker rm -f "$container" 2>/dev/null || true
        done
        log_info "잔여 컨테이너 정리 완료"
    else
        log_info "정리할 잔여 컨테이너 없음"
    fi
}

# 완전 정리 (인프라 스크립트 사용)
full_cleanup() {
    log_step "완전 정리 수행 중..."

    if [ -f "${K3D_SCRIPT_DIR}/scripts/cleanup.sh" ]; then
        cd "${K3D_SCRIPT_DIR}/scripts"
        bash cleanup.sh --force
        log_info "완전 정리 완료"
    else
        log_warn "정리 스크립트를 찾을 수 없습니다."
        log_info "수동 삭제를 수행합니다..."
        delete_cluster
    fi
}

# 사용법 출력
usage() {
    echo "사용법: $0 [OPTIONS]"
    echo ""
    echo "옵션:"
    echo "  -s, --stop       환경 중지 (클러스터 유지, 재시작 가능)"
    echo "  -d, --delete     클러스터 삭제 (완전 제거)"
    echo "  -f, --full       완전 정리 (모든 k3d 리소스 삭제)"
    echo "  -h, --help       도움말 표시"
    echo ""
    echo "옵션 없이 실행 시 대화형으로 선택할 수 있습니다."
    echo ""
    echo "예제:"
    echo "  $0 --stop        # 환경만 중지"
    echo "  $0 --delete      # 클러스터 삭제"
    echo "  $0 --full        # 완전 정리"
    echo ""
}

# 대화형 선택
interactive_mode() {
    echo ""
    echo "========================================"
    echo "테스트 환경 정리 옵션 선택"
    echo "========================================"
    echo ""
    echo "1) 환경 중지 (클러스터 유지, 재시작 가능)"
    echo "2) 클러스터 삭제 (완전 제거)"
    echo "3) 완전 정리 (모든 k3d 리소스 삭제)"
    echo "4) 취소"
    echo ""
    read -p "선택 (1-4): " -n 1 -r
    echo ""

    case $REPLY in
        1)
            stop_environment
            ;;
        2)
            delete_cluster
            ;;
        3)
            full_cleanup
            ;;
        4)
            log_info "취소되었습니다."
            exit 0
            ;;
        *)
            log_error "잘못된 선택입니다."
            exit 1
            ;;
    esac
}

# 메인 함수
main() {
    log_info "=== c4ang-quality-gate 테스트 환경 정리 ==="

    # 인자가 없으면 대화형 모드
    if [ $# -eq 0 ]; then
        interactive_mode
    else
        # 인자 파싱
        case $1 in
            -s|--stop)
                stop_environment
                ;;
            -d|--delete)
                delete_cluster
                ;;
            -f|--full)
                full_cleanup
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                log_error "알 수 없는 옵션: $1"
                usage
                exit 1
                ;;
        esac
    fi

    log_info "=== 정리 완료 ==="
}

# 스크립트 실행
main "$@"
