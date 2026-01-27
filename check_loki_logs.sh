#!/bin/bash

# Loki 로그 수집 확인 스크립트
# 사용법: ./check_loki_logs.sh

LOKI_ADDR="http://192.168.1.13:3100"

echo "=========================================="
echo "Loki 로그 수집 확인"
echo "Loki 주소: ${LOKI_ADDR}"
echo "=========================================="
echo ""

# Loki 서버 연결 확인
echo "1. Loki 서버 연결 확인..."
if curl -s -f "${LOKI_ADDR}/ready" > /dev/null 2>&1; then
    echo "   ✓ Loki 서버 연결 성공"
else
    echo "   ✗ Loki 서버 연결 실패"
    echo "   확인: ${LOKI_ADDR}에 접근 가능한지 확인하세요"
    exit 1
fi
echo ""

# 라벨 확인
echo "2. 라벨 확인..."
echo "   Type 라벨:"
types=$(curl -s "${LOKI_ADDR}/loki/api/v1/label/type/values" 2>/dev/null | jq -r '.data[]' 2>/dev/null)
if [ -z "$types" ]; then
    echo "      (라벨이 없습니다 - 로그가 아직 수집되지 않았을 수 있습니다)"
else
    echo "$types" | sed 's/^/      - /'
fi

echo ""
echo "   Level 라벨:"
levels=$(curl -s "${LOKI_ADDR}/loki/api/v1/label/level/values" 2>/dev/null | jq -r '.data[]' 2>/dev/null)
if [ -z "$levels" ]; then
    echo "      (라벨이 없습니다)"
else
    echo "$levels" | sed 's/^/      - /'
fi

echo ""
echo "   Source 라벨 (최근 15개):"
sources=$(curl -s "${LOKI_ADDR}/loki/api/v1/label/source/values" 2>/dev/null | jq -r '.data[]' 2>/dev/null | head -15)
if [ -z "$sources" ]; then
    echo "      (라벨이 없습니다)"
else
    echo "$sources" | sed 's/^/      - /'
fi
echo ""

# 최근 로그 확인
echo "3. 최근 로그 확인 (최근 5분)..."
START_TIME=$(date -u -v-5M +%s 2>/dev/null || date -u -d '5 minutes ago' +%s)000000000
END_TIME=$(date -u +%s)000000000

# 전체 로그 스트림 수
total_streams=$(curl -s -G "${LOKI_ADDR}/loki/api/v1/query_range" \
  --data-urlencode "query={type=\"info\"}" \
  --data-urlencode "start=${START_TIME}" \
  --data-urlencode "end=${END_TIME}" \
  --data-urlencode "limit=1" 2>/dev/null | jq '.data.result | length' 2>/dev/null)

if [ -z "$total_streams" ] || [ "$total_streams" = "null" ]; then
    echo "   ⚠ 로그 스트림을 확인할 수 없습니다"
else
    echo "   전체 로그 스트림 수: ${total_streams}"
fi

# Level별 로그 확인
echo ""
echo "   Level별 로그 스트림 수:"
for level in lv0 lv1; do
    count=$(curl -s -G "${LOKI_ADDR}/loki/api/v1/query_range" \
      --data-urlencode "query={level=\"${level}\"}" \
      --data-urlencode "start=${START_TIME}" \
      --data-urlencode "end=${END_TIME}" \
      --data-urlencode "limit=1" 2>/dev/null | jq '.data.result | length' 2>/dev/null)
    if [ -z "$count" ] || [ "$count" = "null" ]; then
        echo "      ${level}: 확인 불가"
    else
        echo "      ${level}: ${count} streams"
    fi
done
echo ""

# 최근 로그 샘플
echo "4. 최근 로그 샘플 (최근 5개)..."
recent_logs=$(curl -s -G "${LOKI_ADDR}/loki/api/v1/query_range" \
  --data-urlencode "query={type=\"info\"}" \
  --data-urlencode "start=${START_TIME}" \
  --data-urlencode "end=${END_TIME}" \
  --data-urlencode "limit=5" 2>/dev/null | jq -r '.data.result[].values[][1]' 2>/dev/null | head -5)

if [ -z "$recent_logs" ]; then
    echo "   (최근 로그가 없습니다)"
    echo ""
    echo "   ⚠ 로그가 수집되지 않고 있습니다."
    echo "   확인 사항:"
    echo "   1. Fluentd가 실행 중인가?"
    echo "   2. Fluentd 로그에 에러가 없는가?"
    echo "   3. Fluentd 버퍼 디렉토리 확인: ls -lh /var/lib/fluentd/buffer/loki/"
else
    echo "$recent_logs" | while IFS= read -r line; do
        if [ -n "$line" ]; then
            # 첫 100자만 표시
            echo "   $(echo "$line" | cut -c1-100)..."
        fi
    done
fi
echo ""

# 주요 source 확인
echo "5. 주요 Source별 최근 로그 확인..."
for source in mariadb rabbitmq keystone nova neutron; do
    count=$(curl -s -G "${LOKI_ADDR}/loki/api/v1/query_range" \
      --data-urlencode "query={source=\"${source}\"}" \
      --data-urlencode "start=${START_TIME}" \
      --data-urlencode "end=${END_TIME}" \
      --data-urlencode "limit=1" 2>/dev/null | jq '.data.result | length' 2>/dev/null)
    if [ -n "$count" ] && [ "$count" != "null" ] && [ "$count" -gt 0 ]; then
        echo "   ✓ ${source}: 로그 수집 중"
    else
        echo "   ✗ ${source}: 로그 없음"
    fi
done
echo ""

echo "=========================================="
echo "확인 완료"
echo ""
echo "더 자세한 확인은 다음을 참고하세요:"
echo "  - LogCLI: logcli query '{type=\"info\"}' --limit=50 --since=1h"
echo "  - Grafana Explore에서 LogQL 쿼리 사용"
echo "  - 문서: LOKI_VERIFICATION.md"
echo "=========================================="
