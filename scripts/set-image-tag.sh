#!/bin/bash

# 서비스 이미지 태그 설정 헬퍼 스크립트
# 사용법: ./scripts/set-image-tag.sh customer-service v1.0.0

set -euo pipefail

# 색상 정의
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

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

# 사용법 출력
usage() {
    echo "사용법: $0 <service-name> <image-tag> [--file <path>]"
    echo ""
    echo "인자:"
    echo "  service-name    서비스 이름 (예: customer-service, order-service)"
    echo "  image-tag       이미지 태그 (예: v1.0.0, latest, develop-abc123)"
    echo ""
    echo "옵션:"
    echo "  --file <path>   설정 파일 경로 (기본: config/service-versions.yaml)"
    echo ""
    echo "예제:"
    echo "  $0 customer-service v1.0.0"
    echo "  $0 order-service latest"
    echo "  $0 customer-service develop-abc123 --file config/my-versions.yaml"
    echo ""
}

# 인자 확인
if [ $# -lt 2 ]; then
    log_error "인자가 부족합니다."
    usage
    exit 1
fi

SERVICE_NAME=$1
IMAGE_TAG=$2
VERSIONS_FILE="${3:-config/service-versions.yaml}"

# --file 옵션 처리
if [ "${3:-}" == "--file" ] && [ -n "${4:-}" ]; then
    VERSIONS_FILE=$4
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
VERSIONS_PATH="${PROJECT_ROOT}/${VERSIONS_FILE}"

log_info "서비스 이미지 태그 설정"
log_info "  서비스: ${SERVICE_NAME}"
log_info "  태그: ${IMAGE_TAG}"
log_info "  파일: ${VERSIONS_PATH}"

# yq 설치 확인
if ! command -v yq &> /dev/null; then
    log_warn "yq가 설치되어 있지 않습니다. 수동으로 파일을 편집합니다."
    log_info "yq 설치: brew install yq (macOS) 또는 https://github.com/mikefarah/yq"

    # 수동 편집 안내
    echo ""
    echo "다음 파일을 수동으로 편집하세요:"
    echo "  ${VERSIONS_PATH}"
    echo ""
    echo "예시:"
    echo "  services:"
    echo "    ${SERVICE_NAME}:"
    echo "      image:"
    echo "        tag: \"${IMAGE_TAG}\""
    exit 1
fi

# 파일 존재 확인
if [ ! -f "${VERSIONS_PATH}" ]; then
    log_warn "설정 파일이 존재하지 않습니다. 새로 생성합니다."
    mkdir -p "$(dirname "${VERSIONS_PATH}")"
    cat > "${VERSIONS_PATH}" <<EOF
# 서비스별 이미지 태그 설정
services:
  ${SERVICE_NAME}:
    image:
      repository: c4ang/${SERVICE_NAME}
      tag: "${IMAGE_TAG}"
    enabled: true
EOF
    log_info "설정 파일 생성 완료: ${VERSIONS_PATH}"
    exit 0
fi

# yq로 이미지 태그 업데이트
log_info "이미지 태그 업데이트 중..."

yq eval ".services.${SERVICE_NAME}.image.tag = \"${IMAGE_TAG}\"" -i "${VERSIONS_PATH}"

# 업데이트 확인
UPDATED_TAG=$(yq eval ".services.${SERVICE_NAME}.image.tag" "${VERSIONS_PATH}")

if [ "${UPDATED_TAG}" == "${IMAGE_TAG}" ]; then
    log_info "✅ 이미지 태그 업데이트 완료"
    echo ""
    echo "현재 설정:"
    yq eval ".services.${SERVICE_NAME}" "${VERSIONS_PATH}"
else
    log_error "❌ 이미지 태그 업데이트 실패"
    exit 1
fi

echo ""
log_info "다음 명령어로 테스트를 실행하세요:"
echo "  ./scripts/setup-test-env.sh"
echo "  ./scripts/run-tests.sh"
