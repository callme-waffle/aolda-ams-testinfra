# 로그 수집 현황 분석

실제 `/var/log/kolla` 디렉토리 구조를 기반으로 현재 Fluentd 설정에서 수집되는 로그를 분석합니다.

## 📊 수집되는 로그 종류

### Level 0 (인프라) - 수집됨 ✅

#### 1. MariaDB
- **수집 파일**: `/var/log/kolla/mariadb/mariadb.log`
- **파서**: Multiline (날짜 형식에 따라 mysqld_safe/mysqld로 분리)
- **태그**: `infra.mariadb` → `infra.mariadb.mysqld_safe` 또는 `infra.mariadb.mysqld`
- **메타데이터**: `level=lv0`, `source=mariadb`

#### 1-1. MariaDB Xinetd
- **수집 파일**: `/var/log/kolla/mariadb/xinetd.log`
- **파서**: Multiline (xinetd 형식 파싱)
- **태그**: `infra.mariadb-xinetd`
- **메타데이터**: `level=lv0`, `source=mariadb-xinetd`

#### 1-2. MariaDB Cluster Check
- **수집 파일**: `/var/log/kolla/mariadb/mariadb-clustercheck.log`
- **파서**: 기본 regexp (전체를 Payload로 저장)
- **태그**: `infra.mariadb-clustercheck`
- **메타데이터**: `level=lv0`, `source=mariadb-clustercheck`

#### 2. RabbitMQ
- **수집 파일**: `/var/log/kolla/rabbitmq/rabbit@aolda-control.log`
- **파서**: Multiline (타임스탬프 + 로그 레벨 추출)
  - 추출 필드: `Timestamp`, `log_level`, `Payload`
- **태그**: `infra.rabbit`
- **메타데이터**: `level=lv0`, `source=rabbit`

#### 3. Libvirt
- **수집 파일**: `/var/log/kolla/libvirt/libvirtd.log`
- **파서**: Regexp (타임스탬프, PID, 로그 레벨 추출)
  - 추출 필드: `Timestamp`, `Pid`, `log_level`, `Payload`
  - 시간 형식: `%F %T.%L%z` (예: `2024-01-10 12:34:56.789+0000`)
- **태그**: `infra.libvirt`
- **메타데이터**: `level=lv0`, `source=libvirt`

#### 4. OpenVSwitch
- **수집 파일**: 
  - `/var/log/kolla/openvswitch/ovs-vswitchd.log`
  - `/var/log/kolla/openvswitch/ovsdb-server.log`
- **파서**: Multiline (ISO 8601 형식, 모듈, 로그 레벨 추출)
  - 추출 필드: `Timestamp`, `module`, `log_level`, `Payload`
  - 시간 형식: `%FT%T.%L` (예: `2024-01-10T12:34:56.789`)
- **태그**: `infra.openvswitch`, `infra.openvswitchdb`
- **메타데이터**: `level=lv0`, `source=openvswitch` 또는 `openvswitchdb`

#### 5. Systemd Journal
- **수집**: `/var/log/journal` (시스템 저널)
- **태그**: `journal`
- **메타데이터**: `level=lv0`, `source=systemd`

#### 6. Syslog
- **수집**: UDP 포트 5140으로 수신되는 syslog 메시지
- **태그**: `syslog`
- **메타데이터**: `level=lv0`, `source=syslog`

#### 7. Redis
- **수집 파일**: `/var/log/kolla/redis/redis.log`
- **파서**: Regexp (PID, Role, Timestamp, 로그 레벨 추출)
  - PID: 프로세스 ID (정수)
  - Role: S=Server, C=Child, M=Master, X=Sentinel
  - Timestamp: `10 Jan 2026 11:21:36.045` 형식
  - 로그 레벨: `*` (일반), `#` (경고/에러)
- **태그**: `infra.redis`
- **메타데이터**: `level=lv0`, `source=redis`

#### 8. Redis Sentinel
- **수집 파일**: `/var/log/kolla/redis/redis-sentinel.log`
- **파서**: Regexp (PID, Role, Timestamp, 로그 레벨 추출)
  - PID: 프로세스 ID (정수)
  - Role: S=Server, C=Child, M=Master, X=Sentinel
  - Timestamp: `08 Jan 2026 20:25:26.588` 형식
  - 로그 레벨: `*` (일반), `#` (경고/에러)
- **태그**: `infra.redis-sentinel`
- **메타데이터**: `level=lv0`, `source=redis-sentinel`

### Level 1 (OpenStack 서비스) - 수집됨 ✅

#### 1. Cinder
- **수집 파일**:
  - `cinder-api.log`
  - `cinder-backup.log`
  - `cinder-scheduler.log`
  - `cinder-volume.log`
  - `privsep-helper.log`
- **제외 파일**: `cinder-api-uwsgi.log` (별도 소스로 처리)
- **파서**: Multiline (OpenStack Python 로그 형식)
- **태그**: `kolla.var.log.kolla.cinder.*.log`
- **메타데이터**: `level=lv1`, `source=cinder`

#### 2. Glance
- **수집 파일**:
  - `glance-api.log`
- **제외 파일**: `glance-api-uwsgi.log` (별도 소스로 처리)
- **파서**: Multiline (OpenStack Python 로그 형식)
- **태그**: `kolla.var.log.kolla.glance.*.log`
- **메타데이터**: `level=lv1`, `source=glance`

#### 3. Heat
- **수집 파일**:
  - `heat-api.log`
  - `heat-api-cfn.log`
  - `heat-engine.log`
- **제외 파일**: 
  - `heat-api-uwsgi.log` (별도 소스로 처리)
  - `apache-access.log`, `apache-cfn-access.log`, `apache-error.log`, `apache-cfn-error.log` (별도 소스로 처리)
  - `heat-api-access.log`, `heat-api-cfn-access.log`, `heat-api-error.log` (별도 소스로 처리)
- **파서**: Multiline (OpenStack Python 로그 형식)
- **태그**: `kolla.var.log.kolla.heat.*.log`
- **메타데이터**: `level=lv1`, `source=heat`

#### 4. Keystone
- **수집 파일**:
  - `keystone.log`
- **제외 파일**: 
  - `keystone-uwsgi.log` (별도 소스로 처리)
  - `apache-access.log`, `apache-error.log` (별도 소스로 처리)
  - `keystone-apache-public-access.log`, `keystone-apache-public-error.log` (별도 소스로 처리)
- **파서**: Multiline (OpenStack Python 로그 형식)
- **태그**: `kolla.var.log.kolla.keystone.*.log`
- **메타데이터**: `level=lv1`, `source=keystone`

#### 5. Masakari
- **수집 파일**:
  - `masakari-engine.log`
  - `masakari-hostmonitor.log`
  - `masakari-instancemonitor.log`
  - `masakari-wsgi.log`
  - `privsep-helper.log`
- **제외 파일**: 
  - `masakari-uwsgi.log` (별도 소스로 처리)
  - `apache-access.log`, `apache-error.log` (별도 소스로 처리)
  - `masakari_wsgi_access.log`, `masakari_wsgi_error.log` (별도 소스로 처리)
- **파서**: Multiline (OpenStack Python 로그 형식)
- **태그**: `kolla.var.log.kolla.masakari.*.log`
- **메타데이터**: `level=lv1`, `source=masakari`

#### 6. Neutron
- **수집 파일**:
  - `neutron-server.log`
  - `neutron-dhcp-agent.log`
  - `neutron-l3-agent.log`
  - `neutron-metadata-agent.log`
  - `neutron-metering-agent.log`
  - `neutron-netns-cleanup.log`
  - `neutron-openvswitch-agent.log`
  - `privsep-helper.log`
- **제외 파일**: 
  - `dnsmasq.log` (명시적 제외)
  - `neutron-uwsgi.log` (별도 소스로 처리)
- **파서**: Multiline (OpenStack Python 로그 형식)
- **태그**: `kolla.var.log.kolla.neutron.*.log`
- **메타데이터**: `level=lv1`, `source=neutron`

#### 7. Nova
- **수집 파일**:
  - `nova-api.log`
  - `nova-compute.log`
  - `nova-conductor.log`
  - `nova-metadata.log`
  - `nova-novncproxy.log`
  - `nova-scheduler.log`
- **제외 파일**: 
  - `nova-api-uwsgi.log`, `nova-metadata-uwsgi.log` (별도 소스로 처리)
- **파서**: Multiline (OpenStack Python 로그 형식)
- **태그**: `kolla.var.log.kolla.nova.*.log`
- **메타데이터**: `level=lv1`, `source=nova`

#### 8. Placement
- **수집 파일**:
  - `placement-api.log`
- **제외 파일**: 
  - `placement-api-uwsgi.log` (별도 소스로 처리)
- **파서**: Multiline (OpenStack Python 로그 형식)
- **태그**: `kolla.var.log.kolla.placement.*.log`
- **메타데이터**: `level=lv1`, `source=placement`

### Apache/WSGI Access/Error 로그 - 수집됨 ✅

#### 수집 파일 (와일드카드 패턴)
- `heat/apache-access.log`
- `heat/apache-cfn-access.log`
- `heat/apache-error.log`
- `heat/apache-cfn-error.log`
- `heat/heat-api-access.log`
- `heat/heat-api-cfn-access.log`
- `heat/heat-api-error.log`
- `keystone/apache-access.log`
- `keystone/apache-error.log`
- `keystone/keystone-apache-public-access.log`
- `keystone/keystone-apache-public-error.log`
- `masakari/apache-access.log`
- `masakari/apache-error.log`
- `masakari/masakari_wsgi_access.log`
- `masakari/masakari_wsgi_error.log`
- `skyline/skyline-access.log`
- `skyline/skyline-error.log`
- `skyline/skyline-nginx-access.log`
- `skyline/skyline-nginx-error.log`

---

- **파서**: 기본 regexp (전체를 Payload로 저장)
- **태그**: `kolla.var.log.kolla.*.*-access.log`, `kolla.var.log.kolla.*.*-error.log`, `kolla.var.log.kolla.*.*_access.log`, `kolla.var.log.kolla.*.*_error.log`
- **필터**: 
  - Apache Access/Error (`*-access.log`, `*-error.log`): `Logger=apache.<서비스명>`, `level=lv1`, `source=<서비스명>`
  - WSGI Access/Error (`*_access.log`, `*_error.log`): `Logger=wsgi.<서비스명>`, `level=lv1`, `source=<서비스명>`
- **메타데이터**: 
  - `Hostname`: 호스트명
  - `Logger`: apache 또는 wsgi + 서비스명
  - `programname`: 파일명
  - `type`: info
  - `level`: lv1
  - `source`: 서비스명 (태그에서 자동 추출)

### UWSGI 로그 - 수집됨 ✅

#### 수집 파일
- `cinder/cinder-api-uwsgi.log`
- `glance/glance-api-uwsgi.log` (실제로는 없지만 설정에 포함)
- `heat/heat-api-uwsgi.log` (실제로는 없지만 설정에 포함)
- `keystone/keystone-uwsgi.log` (실제로는 없지만 설정에 포함)
- `masakari/masakari-uwsgi.log` (실제로는 없지만 설정에 포함)
- `neutron/neutron-uwsgi.log` (실제로는 없지만 설정에 포함)
- `nova/nova-api-uwsgi.log`
- `nova/nova-metadata-uwsgi.log`
- `placement/placement-api-uwsgi.log`

---

- **파서**: Regexp (UWSGI 형식 파싱)
    - 추출 필드: `Pid`, `App`, `Req`, `Address`, `User`, `Vars`, `Bytes`, `Timestamp`, `Payload`
- **태그**: `kolla.var.log.kolla.*.*-uwsgi.log`
- **필터**: `Logger=uwsgi.<서비스명>`, `level=lv1`, `source=<서비스명>`
- **메타데이터**: 
  - `Hostname`: 호스트명
  - `Logger`: uwsgi + 서비스명
  - `programname`: 파일명
  - `type`: info
  - `level`: lv1
  - `source`: 서비스명 (태그에서 자동 추출)

## ❌ 수집되지 않는 로그

### 1. Skyline (일부)
- `skyline/skyline.log`
- **이유**: `skyline` 디렉토리가 OpenStack 서비스 와일드카드에 포함되지 않음
- **참고**: Access/Error 로그는 수집됨 (별도 소스로)

### 2. 기타
- `ansible.log` (루트 디렉토리)
- `fluentd/fluentd.log` (자기 자신의 로그)

## 📝 로그 형태 및 파서 매칭

### OpenStack Python 로그 형식
```
2024-01-10 12:34:56.789 12345 INFO nova.api.openstack.compute.servers [req-xxx-xxx user-id tenant-id ...] Payload message
```

**파서**: Multiline
- `format_firstline`: `^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}.\d{3} \d+ \S+ \S+ \[.*\]`
- **시간 형식**: `%F %T.%L` (예: `2024-01-10 12:34:56.789`)
- 추출 필드:
  - `Timestamp`: 타임스탬프
  - `Pid`: 프로세스 ID
  - `log_level`: 로그 레벨 (INFO, ERROR, WARNING 등)
  - `python_module`: Python 모듈명
  - `global_request_id`, `request_id`, `user_id`, `tenant_id`, `domain_id`, `system_scope`, `user_domain`, `project_domain`: 요청 컨텍스트 (선택적)
  - `Payload`: 실제 로그 메시지

### MariaDB 로그 형식
두 가지 형식 지원 (자동 분리):
1. **mysqld_safe** (6자리 날짜): `240110 12:34:56 mysqld_safe ...`
   - 태그: `infra.mariadb.mysqld_safe`
   - 시간 형식: `%y%m%d %k:%M:%S`
2. **mysqld** (8자리 날짜): `2024-01-10 12:34:56 [Note] ...`
   - 태그: `infra.mariadb.mysqld`
   - 시간 형식: `%Y-%m-%d %k:%M:%S`
   - 추출 필드: `Timestamp`, `log_level`, `Payload`
- **처리 과정**: 
  1. 초기 파싱: Multiline로 전체를 Payload로 저장
  2. Retagging: 날짜 형식에 따라 태그 분리
  3. 재파싱: 각 형식에 맞는 파서로 재파싱
  4. 타임스탬프 추가: 파싱된 시간을 `timestamp` 필드로 추가

### MariaDB Xinetd 로그 형식
```
24/01/10@12:34:56: START: /usr/sbin/xinetd ...
24/01/10@12:34:56: EXIT: /usr/sbin/xinetd ...
```
- **파서**: Multiline
- **시간 형식**: `%y/%m/%d@%T` (예: `24/01/10@12:34:56`)
- 추출 필드: `Timestamp`, `Payload`

### Redis 로그 형식
```
8:S 10 Jan 2026 11:21:36.045 * 10 changes in 300 seconds. Saving...
47119:C 10 Jan 2026 11:21:36.050 * DB saved on disk
8:X 08 Jan 2026 20:25:26.588 * +slave slave 172.16.10.12:6379 ...
8:X 08 Jan 2026 23:39:25.009 # +sdown sentinel ...
```
- **파서**: Regexp
- **정규식**: `/^(?:(?<Pid>\d+):(?<Role>[SCMX])\s+(?<Timestamp>\d{1,2}\s+\w{3}\s+\d{4}\s+\d{2}:\d{2}:\d{2}\.\d{3})\s+[*#]\s+)?(?<Payload>.*)$/`
- **시간 형식**: `%d %b %Y %H:%M:%S.%L` (예: `10 Jan 2026 11:21:36.045`)
- 추출 필드:
  - `Pid`: 프로세스 ID (정수 타입)
  - `Role`: 역할 (S=Server, C=Child, M=Master, X=Sentinel)
  - `Timestamp`: 타임스탬프 (일 월 년 시:분:초.밀리초)
  - `Payload`: 실제 로그 메시지
- **로그 레벨**: `*` (일반), `#` (경고/에러)
- **참고**: 타임스탬프가 없는 로그는 전체가 Payload로 저장됨

### RabbitMQ 로그 형식
```
2024-01-10 12:34:56.789 [info] Message content
```
- **파서**: Multiline
- 추출 필드: `Timestamp`, `log_level`, `Payload`
- **참고**: 타임스탬프 형식은 선택적 (타임존 정보 포함 가능)

### OpenVSwitch 로그 형식
```
2024-01-10T12:34:56.789Z|12345|module|level|Payload
```
- **파서**: Multiline
- **시간 형식**: `%FT%T.%L` (ISO 8601, 예: `2024-01-10T12:34:56.789`)
- 추출 필드: `Timestamp`, `module`, `log_level`, `Payload`

### UWSGI 로그 형식
```
[pid: 12345|app: 0|req: 1/10] 127.0.0.1 (user) {10 vars in 1024 bytes} [Wed Jan 10 12:34:56 2024] Payload
```
- **파서**: Regexp
- **시간 형식**: `%c` (로케일 의존적, 예: `Wed Jan 10 12:34:56 2024`)
- 추출 필드: `Pid`, `App`, `Req`, `Address`, `User`, `Vars`, `Bytes`, `Timestamp`, `Payload`
- **참고**: 타임스탬프가 없는 로그는 전체가 Payload로 저장됨

## 📤 OUTPUT - Loki

### 설정
- **타입**: Loki
- **URL**: `http://172.32.0.247:3100`
- **라벨**: 
  - `type`: 레코드의 `type` 필드 값
  - `level`: 레코드의 `level` 필드 값 (lv0 또는 lv1)
  - `source`: 레코드의 `source` 필드 값 (서비스명)
- **버퍼링**:
  - 타입: 파일 기반
  - 경로: `/var/lib/fluentd/buffer/loki`
  - 플러시 간격: 10초
  - 청크 크기 제한: 1MB
  - 재시도 횟수: 3회

### 매칭 규칙
- `<match **>`: 모든 태그의 로그를 Loki로 전송

## 🔧 개선 권장사항

1. **Skyline 로그 추가**: `skyline` 디렉토리를 OpenStack 서비스에 포함하여 `skyline.log` 수집

