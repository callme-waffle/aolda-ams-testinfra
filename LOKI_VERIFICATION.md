# Loki 로그 수집 확인 가이드

Loki에서 로그가 정상적으로 수집되고 있는지 확인하는 방법입니다.

## 1. LogCLI를 사용한 확인 (권장)

### LogCLI 설치
```bash
# Linux
wget https://github.com/grafana/loki/releases/download/v2.9.0/logcli-linux-amd64.zip
unzip logcli-linux-amd64.zip
sudo mv logcli /usr/local/bin/

# macOS
brew install logcli
```

### 기본 사용법

#### 1) 라벨 목록 확인
```bash
# Loki 서버 설정
export LOKI_ADDR=http://192.168.1.13:3100

# 사용 가능한 라벨 확인
logcli labels
```

#### 2) 특정 라벨로 로그 조회
```bash
# type 라벨 확인
logcli labels type

# level 라벨 확인
logcli labels level

# source 라벨 확인
logcli labels source
```

#### 3) 로그 쿼리
```bash
# 모든 로그 조회 (최근 1시간)
logcli query '{job="fluentd"}' --limit=100 --since=1h

# 특정 type의 로그 조회
logcli query '{type="info"}' --limit=50 --since=1h

# 특정 level의 로그 조회
logcli query '{level="lv1"}' --limit=50 --since=1h

# 특정 source의 로그 조회
logcli query '{source="keystone"}' --limit=50 --since=1h

# 여러 조건 조합
logcli query '{type="info", level="lv1", source="nova"}' --limit=50 --since=1h
```

#### 4) 로그 스트림 목록 확인
```bash
# 모든 로그 스트림 확인
logcli series

# 특정 라벨 조합의 스트림 확인
logcli series --match='{type="info", level="lv0"}'
```

#### 5) 실시간 로그 모니터링
```bash
# 실시간으로 로그 tail
logcli query '{job="fluentd"}' --tail --since=5m
```

## 2. HTTP API를 사용한 확인

### cURL을 사용한 확인

#### 1) 라벨 목록 조회
```bash
# 모든 라벨 조회
curl -G -s "http://192.168.1.13:3100/loki/api/v1/labels" | jq

# 특정 라벨의 값 조회
curl -G -s "http://192.168.1.13:3100/loki/api/v1/label/type/values" | jq
curl -G -s "http://192.168.1.13:3100/loki/api/v1/label/level/values" | jq
curl -G -s "http://192.168.1.13:3100/loki/api/v1/label/source/values" | jq
```

#### 2) 로그 쿼리
```bash
# 최근 1시간의 로그 조회
curl -G -s "http://192.168.1.13:3100/loki/api/v1/query_range" \
  --data-urlencode 'query={type="info"}' \
  --data-urlencode 'start='$(date -u -d '1 hour ago' +%s)'000000000' \
  --data-urlencode 'end='$(date -u +%s)'000000000' \
  --data-urlencode 'limit=100' | jq

# 특정 source의 로그 조회
curl -G -s "http://192.168.1.13:3100/loki/api/v1/query_range" \
  --data-urlencode 'query={source="mariadb"}' \
  --data-urlencode 'start='$(date -u -d '1 hour ago' +%s)'000000000' \
  --data-urlencode 'end='$(date -u +%s)'000000000' \
  --data-urlencode 'limit=50' | jq
```

#### 3) 로그 스트림 목록
```bash
# 모든 스트림 조회
curl -G -s "http://192.168.1.13:3100/loki/api/v1/series" | jq

# 특정 라벨 매칭 스트림 조회
curl -G -s "http://192.168.1.13:3100/loki/api/v1/series" \
  --data-urlencode 'match[]={type="info", level="lv1"}' | jq
```

## 3. Grafana Explore를 사용한 확인

### Grafana 접속
1. Grafana에 접속 (일반적으로 `http://192.168.1.13:3000`)
2. 좌측 메뉴에서 **Explore** 클릭
3. 데이터 소스로 **Loki** 선택

### LogQL 쿼리 예시

#### 기본 쿼리
```logql
# 모든 로그
{job="fluentd"}

# 특정 type
{type="info"}

# 특정 level
{level="lv1"}

# 특정 source
{source="keystone"}

# 여러 조건 조합
{type="info", level="lv1", source="nova"}
```

#### 로그 라인 필터링
```logql
# 특정 텍스트 포함
{source="mariadb"} |= "ERROR"

# 정규식 매칭
{source="nova"} |~ "error|ERROR|Error"

# 특정 필드 포함
{type="info"} | json | level="ERROR"
```

#### 집계 쿼리
```logql
# 로그 라인 수 카운트
sum(count_over_time({type="info"}[5m]))

# rate 계산
rate({source="keystone"}[5m])

# topk (상위 N개)
topk(10, sum by (source) (count_over_time({type="info"}[5m])))
```

## 4. 빠른 확인 스크립트

### check_loki_logs.sh
```bash
#!/bin/bash

LOKI_ADDR="http://192.168.1.13:3100"

echo "=== Loki 라벨 확인 ==="
echo "Type 라벨:"
curl -s "${LOKI_ADDR}/loki/api/v1/label/type/values" | jq -r '.data[]' | head -10

echo -e "\nLevel 라벨:"
curl -s "${LOKI_ADDR}/loki/api/v1/label/level/values" | jq -r '.data[]'

echo -e "\nSource 라벨 (최근 10개):"
curl -s "${LOKI_ADDR}/loki/api/v1/label/source/values" | jq -r '.data[]' | head -10

echo -e "\n=== 최근 로그 확인 (최근 5분) ==="
START_TIME=$(date -u -d '5 minutes ago' +%s)000000000
END_TIME=$(date -u +%s)000000000

echo "전체 로그 수:"
curl -s -G "${LOKI_ADDR}/loki/api/v1/query_range" \
  --data-urlencode "query={type=\"info\"}" \
  --data-urlencode "start=${START_TIME}" \
  --data-urlencode "end=${END_TIME}" \
  --data-urlencode "limit=1" | jq '.data.result | length'

echo -e "\nLevel별 로그 수:"
for level in lv0 lv1; do
  count=$(curl -s -G "${LOKI_ADDR}/loki/api/v1/query_range" \
    --data-urlencode "query={level=\"${level}\"}" \
    --data-urlencode "start=${START_TIME}" \
    --data-urlencode "end=${END_TIME}" \
    --data-urlencode "limit=1" | jq '.data.result | length')
  echo "  ${level}: ${count} streams"
done

echo -e "\n=== 최근 로그 샘플 (최근 10개) ==="
curl -s -G "${LOKI_ADDR}/loki/api/v1/query_range" \
  --data-urlencode "query={type=\"info\"}" \
  --data-urlencode "start=${START_TIME}" \
  --data-urlencode "end=${END_TIME}" \
  --data-urlencode "limit=10" | jq -r '.data.result[].values[][1]' | head -10
```

### 사용법
```bash
chmod +x check_loki_logs.sh
./check_loki_logs.sh
```

## 5. 확인 체크리스트

### 기본 확인 사항
- [ ] Loki 서버가 실행 중인가? (`curl http://192.168.1.13:3100/ready`)
- [ ] Fluentd가 실행 중이고 에러가 없는가?
- [ ] 라벨이 정상적으로 생성되었는가? (`type`, `level`, `source`)
- [ ] 최근 로그가 수집되고 있는가?

### 라벨별 확인
- [ ] `type="info"` 로그가 있는가?
- [ ] `level="lv0"` 로그가 있는가?
- [ ] `level="lv1"` 로그가 있는가?
- [ ] 주요 `source` 값들이 있는가? (mariadb, rabbitmq, keystone, nova, neutron 등)

### 로그 품질 확인
- [ ] 로그 메시지가 정상적으로 파싱되었는가?
- [ ] 타임스탬프가 정확한가?
- [ ] 필요한 필드가 모두 포함되어 있는가?

## 6. 문제 해결

### 로그가 수집되지 않는 경우

1. **Fluentd 연결 확인**
   ```bash
   # Fluentd 로그 확인
   tail -f /var/log/fluentd/fluentd.log
   
   # Fluentd 버퍼 확인
   ls -lh /var/lib/fluentd/buffer/loki/
   ```

2. **Loki 연결 테스트**
   ```bash
   # Loki 헬스 체크
   curl http://192.168.1.13:3100/ready
   
   # Loki 메트릭 확인
   curl http://192.168.1.13:3100/metrics | grep loki
   ```

3. **네트워크 연결 확인**
   ```bash
   # 포트 접근 확인
   telnet 192.168.1.13 3100
   # 또는
   nc -zv 192.168.1.13 3100
   ```

### 로그가 중복되는 경우
- Fluentd 설정에서 동일한 로그가 여러 번 매칭되는지 확인
- `pos_file` 경로가 중복되지 않는지 확인

### 라벨이 없는 경우
- Fluentd output 설정에서 `<label>` 섹션이 올바른지 확인
- 레코드에 `type`, `level`, `source` 필드가 있는지 확인

## 7. 유용한 LogQL 쿼리 모음

```logql
# 최근 1시간 동안의 에러 로그
{type="info"} |~ "error|ERROR|Error|CRITICAL|FATAL"

# 특정 서비스의 최근 로그
{source="keystone"} | limit 100

# Level별 로그 분포
sum by (level) (count_over_time({type="info"}[1h]))

# Source별 로그 분포
sum by (source) (count_over_time({type="info"}[1h]))

# 시간대별 로그 수
sum(count_over_time({type="info"}[5m]))

# 최근 10분간 가장 많은 로그를 생성한 source
topk(5, sum by (source) (count_over_time({type="info"}[10m])))
```

## 참고 자료

- [Loki LogQL 문서](https://grafana.com/docs/loki/latest/logql/)
- [LogCLI 문서](https://grafana.com/docs/loki/latest/getting-started/logcli/)
- [Loki API 문서](https://grafana.com/docs/loki/latest/api/)
