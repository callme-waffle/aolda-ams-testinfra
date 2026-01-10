# Fluentd 설정 가이드

이 문서는 Fluent Bit 설정을 Fluentd로 변환한 설정 파일의 설치 및 사용 방법을 설명합니다.

## 사전 요구사항

### 1. Fluentd 설치

```bash
# Ubuntu/Debian
curl -L https://toolbelt.treasuredata.com/sh/install-ubuntu-focal-td-agent4.sh | sh

# 또는 gem으로 설치
gem install fluentd
```

### 2. 필수 플러그인 설치

Loki 출력을 위해 다음 플러그인이 필요합니다:

```bash
fluent-gem install fluent-plugin-loki
```

또는 td-agent를 사용하는 경우:

```bash
sudo td-agent-gem install fluent-plugin-loki
```

### 3. 디렉토리 생성

```bash
sudo mkdir -p /var/run/fluentd
sudo mkdir -p /var/lib/fluentd/buffer/loki
sudo chown -R fluentd:fluentd /var/run/fluentd /var/lib/fluentd
```

## 설정 파일 배치

```bash
# 설정 파일을 Fluentd 설정 디렉토리로 복사
sudo cp fluentd.conf /etc/td-agent/td-agent.conf

# 또는 Fluentd를 직접 사용하는 경우
sudo cp fluentd.conf /etc/fluent/fluent.conf
```

## 설정 파일 구조

### Inputs (로그 수집)
- **Level 0 (인프라)**: MySQL, RabbitMQ, System 로그
- **Level 1 (OpenStack)**: Apache2, Keystone, Neutron, Nova, Placement 로그

### Filters (메타데이터 추가)
각 로그에 다음 메타데이터를 추가:
- `type`: info
- `level`: lv0 또는 lv1
- `source`: 서비스명 (mysql, rabbitmq, system, apache2, keystone, neutron, nova, placement)

### Output (Loki 전송)
- **호스트**: 172.32.0.247
- **포트**: 3100
- **라벨**: type, level, source를 라벨로 사용
- **버퍼**: 파일 기반 버퍼링 (10초마다 플러시)

## 실행

### td-agent 사용
```bash
sudo systemctl start td-agent
sudo systemctl status td-agent
```

### Fluentd 직접 사용
```bash
fluentd -c /etc/fluent/fluent.conf
```

## 로그 확인

```bash
# Fluentd 로그 확인
sudo tail -f /var/log/td-agent/td-agent.log

# 또는
sudo journalctl -u td-agent -f
```

## 문제 해결

### 1. 플러그인 오류
```
error_class=Fluent::PluginNotFound error="unknown output plugin 'loki'"
```
→ `fluent-plugin-loki` 플러그인을 설치하세요.

### 2. 권한 오류
```
Permission denied @ rb_sysopen
```
→ 로그 파일과 디렉토리 권한을 확인하세요.

### 3. Loki 연결 오류
→ Loki 서버(172.32.0.247:3100)가 실행 중인지 확인하세요.

## Fluent Bit과의 차이점

| 항목 | Fluent Bit | Fluentd |
|------|-----------|---------|
| 설정 형식 | YAML | XML-like 태그 |
| 모듈화 | 파일 분리 | 단일 파일 |
| 플러그인 | 내장 | 외부 플러그인 필요 |
| 리소스 | 경량 | 더 많은 리소스 |

## 참고사항

- Fluent Bit 설정 파일들은 `fluentbit/` 디렉토리에 그대로 유지됩니다.
- Fluentd 설정은 `fluentd.conf` 파일 하나로 통합되었습니다.
- 모든 로그는 동일한 Loki 인스턴스로 전송됩니다.

