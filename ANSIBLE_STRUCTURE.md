# Fluentd Ansible 구조

이 디렉토리는 Ansible을 통해 Fluentd 설정 파일을 생성하기 위한 템플릿 구조입니다.

## 디렉토리 구조

```
conf/
├── input/          # 입력 소스 설정
│   ├── 01-syslog.conf.j2
│   ├── 02-mariadb.conf.j2
│   ├── 03-rabbitmq.conf.j2
│   ├── 04-redis.conf.j2
│   ├── 05-libvirt.conf.j2
│   ├── 06-openvswitch.conf.j2
│   ├── 07-systemd.conf.j2
│   ├── 08-openstack-services.conf.j2
│   ├── 09-apache-wsgi.conf.j2
│   └── 10-uwsgi.conf.j2
├── filter/         # 필터 설정
│   ├── 00-record_transformer.conf.j2
│   ├── 01-mariadb-parser.conf.j2
│   ├── 02-apache-wsgi-metadata.conf.j2
│   └── 03-uwsgi-metadata.conf.j2
└── output/         # 출력 설정
    └── 00-loki.conf.j2
fluentd.conf.j2     # 메인 템플릿 (모든 파일 include)
```

## Ansible Task 구조

Ansible task에서 다음과 같이 사용합니다:

```yaml
- name: Copying over fluentd.conf
  vars:
    # Inputs
    fluentd_input_files: "{{ default_input_files_enabled | customise_fluentd(customised_input_files) }}"
    default_input_files_enabled: "{{ default_input_files | selectattr('enabled') | map(attribute='name') | list }}"
    default_input_files:
      - name: "conf/input/01-syslog.conf.j2"
        enabled: true
      - name: "conf/input/02-mariadb.conf.j2"
        enabled: true
      - name: "conf/input/03-rabbitmq.conf.j2"
        enabled: true
      - name: "conf/input/04-redis.conf.j2"
        enabled: true
      - name: "conf/input/05-libvirt.conf.j2"
        enabled: "{{ enable_nova | bool and enable_nova_libvirt_container | bool }}"
      - name: "conf/input/06-openvswitch.conf.j2"
        enabled: true
      - name: "conf/input/07-systemd.conf.j2"
        enabled: "{{ enable_fluentd_systemd | bool }}"
      - name: "conf/input/08-openstack-services.conf.j2"
        enabled: true
      - name: "conf/input/09-apache-wsgi.conf.j2"
        enabled: true
      - name: "conf/input/10-uwsgi.conf.j2"
        enabled: true
    customised_input_files: "{{ find_custom_fluentd_inputs.files | map(attribute='path') | list }}"
    
    # Filters
    fluentd_filter_files: "{{ default_filter_files | customise_fluentd(customised_filter_files) }}"
    default_filter_files:
      - "conf/filter/00-record_transformer.conf.j2"
      - "conf/filter/01-mariadb-parser.conf.j2"
      - "conf/filter/02-apache-wsgi-metadata.conf.j2"
      - "conf/filter/03-uwsgi-metadata.conf.j2"
    customised_filter_files: "{{ find_custom_fluentd_filters.files | map(attribute='path') | list }}"
    
    # Outputs
    fluentd_output_files: "{{ default_output_files_enabled | customise_fluentd(customised_output_files) }}"
    default_output_files_enabled: "{{ default_output_files | selectattr('enabled') | map(attribute='name') | list }}"
    default_output_files:
      - name: "conf/output/00-loki.conf.j2"
        enabled: true
    customised_output_files: "{{ find_custom_fluentd_outputs.files | map(attribute='path') | list }}"
  template:
    src: "fluentd.conf.j2"
    dest: "{{ node_config_directory }}/fluentd/fluentd.conf"
    mode: "0660"
  become: true
```

## 파일 설명

### Inputs (입력 소스)

#### 01-syslog.conf.j2
- Syslog 수신 설정
- UDP 포트 5140
- 변수: `fluentd_syslog_bind`

#### 02-mariadb.conf.j2
- MariaDB 로그 수집
- MariaDB Xinetd 로그
- MariaDB Cluster Check 로그

#### 03-rabbitmq.conf.j2
- RabbitMQ 로그 수집
- 변수: `rabbitmq_hostname`

#### 04-redis.conf.j2
- Redis 로그 수집
- Redis Sentinel 로그 수집

#### 05-libvirt.conf.j2
- Libvirt 로그 수집
- 조건부 활성화: `enable_nova` 및 `enable_nova_libvirt_container`

#### 06-openvswitch.conf.j2
- OpenVSwitch vswitchd 로그
- OpenVSwitch DB Server 로그

#### 07-systemd.conf.j2
- Systemd Journal 수집
- 조건부 활성화: `enable_fluentd_systemd`

#### 08-openstack-services.conf.j2
- OpenStack Python 서비스 로그
- Cinder, Glance, Heat, Keystone, Masakari, Neutron, Nova, Placement

#### 09-apache-wsgi.conf.j2
- Apache Access/Error 로그
- WSGI Access/Error 로그

#### 10-uwsgi.conf.j2
- UWSGI 로그

### Filters (필터)

#### 00-record_transformer.conf.j2
- OpenStack 서비스 메타데이터 추가
- 인프라 서비스 메타데이터 추가
- Syslog 메타데이터 추가
- Systemd Journal 메타데이터 추가

#### 01-mariadb-parser.conf.j2
- MariaDB 로그 재태깅 (mysqld_safe/mysqld)
- MariaDB 로그 재파싱
- 타임스탬프 추가

#### 02-apache-wsgi-metadata.conf.j2
- Apache Access/Error 로그 메타데이터 추가
- WSGI Access/Error 로그 메타데이터 추가

#### 03-uwsgi-metadata.conf.j2
- UWSGI 로그 메타데이터 추가

### Outputs (출력)

#### 00-loki.conf.j2
- Loki 출력 설정
- 변수:
  - `loki_host` (기본값: 172.32.0.247)
  - `loki_port` (기본값: 3100)
  - `fluentd_buffer_path` (기본값: /var/lib/fluentd/buffer/loki)
  - `fluentd_flush_interval` (기본값: 10s)
  - `fluentd_chunk_limit_size` (기본값: 1M)
  - `fluentd_retry_max_times` (기본값: 3)

## Jinja2 변수

템플릿에서 사용 가능한 변수:

- `fluentd_syslog_bind`: Syslog 바인드 주소 (기본값: 172.16.10.12)
- `rabbitmq_hostname`: RabbitMQ 호스트명 (기본값: aolda-control)
- `loki_host`: Loki 호스트 (기본값: 172.32.0.247)
- `loki_port`: Loki 포트 (기본값: 3100)
- `fluentd_buffer_path`: 버퍼 경로 (기본값: /var/lib/fluentd/buffer/loki)
- `fluentd_flush_interval`: 플러시 간격 (기본값: 10s)
- `fluentd_chunk_limit_size`: 청크 크기 제한 (기본값: 1M)
- `fluentd_retry_max_times`: 재시도 횟수 (기본값: 3)

## 사용 방법

1. Ansible playbook에서 위의 task를 사용
2. 각 파일의 `enabled` 속성으로 활성화/비활성화 제어
3. 커스텀 파일은 `customised_*_files` 변수로 추가 가능
4. `fluentd.conf.j2`가 모든 파일을 include하여 최종 설정 생성

