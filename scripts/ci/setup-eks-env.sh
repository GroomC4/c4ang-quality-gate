#!/bin/bash
# =============================================================================
# CI용 EKS 환경 설정 스크립트
# =============================================================================
#
# GitHub Actions에서 EKS 클러스터에 연결하여 E2E 테스트를 실행합니다.
# AWS 자격증명이 이미 설정되어 있어야 합니다.
#
# 사용법:
#   ./setup-eks-env.sh
#
# 환경변수:
#   AWS_REGION          - AWS 리전 (기본: ap-northeast-2)
#   EKS_CLUSTER_NAME    - EKS 클러스터 이름 (필수)
#   NAMESPACE           - 테스트 네임스페이스 (기본: ecommerce)
# =============================================================================

set -euo pipefail

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 설정
AWS_REGION="${AWS_REGION:-ap-northeast-2}"
EKS_CLUSTER_NAME="${EKS_CLUSTER_NAME:-}"
NAMESPACE="${NAMESPACE:-ecommerce}"

# 로그 함수
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "\n${CYAN}▶ $1${NC}"; }

# =============================================================================
# 사전 검사
# =============================================================================

check_prerequisites() {
    log_step "사전 요구사항 확인"

    # EKS 클러스터 이름 확인
    if [ -z "$EKS_CLUSTER_NAME" ]; then
        log_error "EKS_CLUSTER_NAME 환경변수가 설정되지 않았습니다."
        exit 1
    fi

    # AWS CLI 확인
    if ! command -v aws &>/dev/null; then
        log_error "AWS CLI가 설치되지 않았습니다."
        exit 1
    fi

    # kubectl 확인
    if ! command -v kubectl &>/dev/null; then
        log_error "kubectl이 설치되지 않았습니다."
        exit 1
    fi

    # AWS 자격증명 확인
    if ! aws sts get-caller-identity &>/dev/null; then
        log_error "AWS 자격증명이 유효하지 않습니다."
        exit 1
    fi

    log_success "사전 요구사항 확인 완료"
}

# =============================================================================
# EKS 클러스터 연결
# =============================================================================

connect_to_eks() {
    log_step "EKS 클러스터 연결"

    log_info "클러스터: ${EKS_CLUSTER_NAME} (${AWS_REGION})"

    # kubeconfig 업데이트
    aws eks update-kubeconfig \
        --name "${EKS_CLUSTER_NAME}" \
        --region "${AWS_REGION}"

    # 연결 확인
    if kubectl cluster-info &>/dev/null; then
        log_success "EKS 클러스터 연결 성공"
    else
        log_error "EKS 클러스터에 연결할 수 없습니다."
        exit 1
    fi

    # 노드 상태 확인
    log_info "클러스터 노드 상태:"
    kubectl get nodes
}

# =============================================================================
# 네임스페이스 및 서비스 확인
# =============================================================================

verify_services() {
    log_step "서비스 상태 확인"

    # 네임스페이스 확인
    if ! kubectl get namespace "${NAMESPACE}" &>/dev/null; then
        log_error "네임스페이스가 존재하지 않습니다: ${NAMESPACE}"
        exit 1
    fi

    log_info "네임스페이스: ${NAMESPACE}"

    # Pod 상태 확인
    log_info "Pod 상태:"
    kubectl get pods -n "${NAMESPACE}"

    # Running 상태 Pod 수 확인
    local running_pods
    running_pods=$(kubectl get pods -n "${NAMESPACE}" --no-headers 2>/dev/null | grep -c "Running" || echo "0")

    if [ "$running_pods" -eq 0 ]; then
        log_warn "실행 중인 Pod가 없습니다."
    else
        log_success "${running_pods}개 Pod 실행 중"
    fi

    # 서비스 목록
    log_info "서비스 목록:"
    kubectl get svc -n "${NAMESPACE}"
}

# =============================================================================
# 결과 출력
# =============================================================================

print_summary() {
    log_step "EKS 환경 설정 완료"

    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}  EKS E2E 테스트 환경 준비 완료${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    echo -e "${GREEN}Cluster:${NC} ${EKS_CLUSTER_NAME}"
    echo -e "${GREEN}Region:${NC} ${AWS_REGION}"
    echo -e "${GREEN}Namespace:${NC} ${NAMESPACE}"
    echo ""
    echo -e "${GREEN}다음 단계:${NC}"
    echo "  KARATE_ENV=eks-staging ./gradlew test"
    echo ""
}

# =============================================================================
# Main
# =============================================================================

main() {
    log_info "EKS E2E 테스트 환경 설정 시작"

    check_prerequisites
    connect_to_eks
    verify_services
    print_summary

    log_success "EKS 환경 설정 완료"
}

main "$@"
