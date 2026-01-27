# conf2 디렉토리 구조

이 디렉토리는 원본 OpenStack Kolla Fluentd 설정의 태그 구조를 반영한 filter와 output 설정을 포함합니다.

## 태그 흐름

### 초기 태그 → 필터 후 최종 태그

1. **Syslog**: `syslog` → `syslog.{{ facility }}.**`
2. **MariaDB**: `infra.mariadb` → `infra.mariadb.mysqld` / `infra.mariadb.mysqld_safe`
3. **RabbitMQ**: `infra.rabbit` → `infra.rabbit`
4. **Redis**: 없음 → 없음 (커스텀 필요)
5. **Libvirt**: `infra.libvirt` → `infra.libvirt`
6. **Open vSwitch**: `infra.openvswitch` → `infra.openvswitch`
7. **Systemd**: `journal` → `fluent.journal.*`
8. **OpenStack 서비스**: `kolla.*` → `apache_access` / `wsgi_access` / `openstack_python`
9. **Apache-WSGI**: `kolla.*` → `apache_access` / `wsgi_access`
10. **UWSGI**: `kolla.*` → `wsgi_access` / `openstack_python`

## Filter 파일 구조

### 00-record_transformer.conf
- OpenStack 서비스 메타데이터 추가 (`kolla.var.log.kolla.*.*.log`)
  - `type`: info
  - `level`: lv1
  - `source`: 서비스명 (tag_parts[4])
- Apache/WSGI Access/Error 로그 메타데이터 추가
  - `type`: info
  - `level`: lv1
  - `source`: 서비스명 (tag_parts[4])
- UWSGI 로그 메타데이터 추가
  - `type`: info
  - `level`: lv1
  - `source`: 서비스명 (tag_parts[4])
- 인프라 서비스 메타데이터 추가 (`infra.**`)
  - `type`: info
  - `level`: lv0
  - `source`: 서비스명 (tag_parts[1] 또는 tag_parts[4])
- Syslog 메타데이터 추가 (`syslog.**`)
  - `type`: info
  - `level`: lv0
  - `source`: syslog
- Syslog HAProxy 메타데이터 추가 (`syslog.local1.**`)
- Systemd Journal 메타데이터 추가 (`journal.**`, `fluent.**`)
  - `type`: info
  - `level`: lv0
  - `source`: systemd

### 01-rewrite.conf
- OpenStack 서비스 태그 재작성 (`kolla.var.log.kolla.*.*.log` → `apache_access` / `wsgi_access` / `openstack_python`)
- MariaDB 태그 재작성 (`infra.mariadb` → `infra.mariadb.mysqld` / `infra.mariadb.mysqld_safe`)

### 02-parser.conf
- MariaDB 로그 파싱 (mysqld_safe, mysqld 형식)
- 타임스탬프 추가

### 03-format.conf
- Apache Access 로그 포맷팅 (Grok 패턴)
- WSGI Access 로그 포맷팅 (Grok 패턴)

## Output 파일 구조

### 00-local.conf
- HAProxy 로그를 로컬 파일과 Loki에 동시 전송 (`syslog.local1.**`)
- Loki URL: `http://192.168.1.13:3100`
- 라벨: `type`, `level`, `source`

### 01-loki.conf
- 모든 필터링된 로그를 Loki로 전송
- Match 패턴: `apache_access`, `wsgi_access`, `openstack_python`, `infra.**`, `syslog.**`, `fluent.journal.**`
- Loki URL: `http://192.168.1.13:3100`
- 라벨: `type`, `level`, `source`

## 사용 방법

Ansible task에서 다음과 같이 사용:

```yaml
- name: Copying over fluentd.conf
  vars:
    # Filters
    fluentd_filter_files: "{{ default_filter_files | customise_fluentd(customised_filter_files) }}"
    default_filter_files:
      - "conf2/filter/00-record_transformer.conf"
      - "conf2/filter/01-rewrite.conf"
      - "conf2/filter/02-parser.conf"
      - "conf2/filter/03-format.conf"
    customised_filter_files: "{{ find_custom_fluentd_filters.files | map(attribute='path') | list }}"
    
    # Outputs
    fluentd_output_files: "{{ default_output_files_enabled | customise_fluentd(customised_output_files) }}"
    default_output_files_enabled: "{{ default_output_files | selectattr('enabled') | map(attribute='name') | list }}"
    default_output_files:
      - name: "conf2/output/00-local.conf"
        enabled: true
      - name: "conf2/output/01-loki.conf"
        enabled: true
    customised_output_files: "{{ find_custom_fluentd_outputs.files | map(attribute='path') | list }}"
  template:
    src: "fluentd.conf.j2"
    dest: "{{ node_config_directory }}/fluentd/fluentd.conf"
    mode: "0660"
  become: true
```

## 태그 매칭 순서

1. Input에서 초기 태그 생성 (`kolla.*`, `infra.*`, `syslog`, `journal`)
2. Filter 00: 메타데이터 추가
3. Filter 01: 태그 재작성 (rewrite_tag_filter)
4. Filter 02: 로그 파싱 (parser)
5. Filter 03: 로그 포맷팅 (grok)
6. Output: 최종 태그에 따라 OpenSearch로 전송
