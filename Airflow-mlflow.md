mlflow with airflow on seperate docker file.
```
docker network create mlflow-airflow-net
```
create ```docker_compose_mlflow.yaml``` file

```
version: '3.8'

services:
  mlflow:
    build: .    
    container_name: mlflow
    ports:
      - "5000:5000"
    volumes:
      - /Users/simamohammadaminifard/data:/mlflow/artifacts
    environment:
      MLFLOW_BACKEND_STORE_URI: mysql+pymysql://root:mypass@host.docker.internal:3306/mlflowdb
      MLFLOW_ARTIFACT_ROOT: /mlflow/artifacts
    command: >
      mlflow server
      --host 0.0.0.0
      --port 5000
      --backend-store-uri mysql+pymysql://root:mypass@host.docker.internal:3306/mlflowdb
      --default-artifact-root /mlflow/artifacts
    restart: always
    networks:
      - mlflow-airflow-net

networks:
  mlflow-airflow-net:
    external: true
```

then create a dtabase in mysql nameit mlflow  
```mysql -u root -p
#mypass  enter your password for your mysql database
CREATE DATABASE mlflowdb;
```
then in the same folder that we have made our mlflow.yaml file we make a file we name it Dockerfile then we put this information in it:



```
FROM ghcr.io/mlflow/mlflow:latest

RUN pip install pymysql

```



Then we make airflwo docker compose.yaml file


```
# Feel free to modify this file to suit your needs.
---
x-airflow-common:
  &airflow-common
  build: .
  environment:
    &airflow-common-env
    AIRFLOW__CORE__EXECUTOR: CeleryExecutor
    AIRFLOW__DATABASE__SQL_ALCHEMY_CONN: postgresql+psycopg2://airflow:airflow@postgres/airflow
    AIRFLOW__CELERY__RESULT_BACKEND: db+postgresql://airflow:airflow@postgres/airflow
    AIRFLOW__CELERY__BROKER_URL: redis://:@redis:6379/0
    AIRFLOW__CORE__FERNET_KEY: ''
    AIRFLOW__CORE__DAGS_ARE_PAUSED_AT_CREATION: 'true'
    AIRFLOW__CORE__LOAD_EXAMPLES: 'false'
    AIRFLOW__API__AUTH_BACKENDS: 'airflow.api.auth.backend.basic_auth,airflow.api.auth.backend.session'
    AIRFLOW__METRICS__STATSD_ON: "True"
    AIRFLOW__WEBSERVER__WORKERS: 2
    AIRFLOW__METRICS__STATSD_PORT: 9125
    AIRFLOW__EMAIL__EMAIL_BACKEND: 'airflow.utils.email.send_email_smtp'
    AIRFLOW__EMAIL__EMAIL_CONN_ID: 'smtp_default'
    AIRFLOW__SMTP__SMTP_HOST: 'smtp.gmail.com'
    AIRFLOW__SMTP__SMTP_STARTTLS: 'True'
    AIRFLOW__SMTP__SMTP_SSL: 'False'
    AIRFLOW__SMTP__SMTP_USER: 'aminisima1365@gmail.com'
    AIRFLOW__SMTP__SMTP_PASSWORD: 'xbbt zsxz kpfw qsre'
    AIRFLOW__SMTP__SMTP_PORT: 587
    AIRFLOW__SMTP__SMTP_MAIL_FROM: 'aminisima1365@gmail.com'
    AIRFLOW__CELERY__WORKER_CONCURRENCY: 24
    AIRFLOW__CORE__PARALLELISM: 32
    AIRFLOW__CORE__DAG_CONCURRENCY: 24
    AIRFLOW__CORE__MAX_ACTIVE_TASKS_PER_DAG: 24
    AIRFLOW__SCHEDULER__ENABLE_HEALTH_CHECK: 'true'
    _PIP_ADDITIONAL_REQUIREMENTS: ${_PIP_ADDITIONAL_REQUIREMENTS:-}
  volumes:
    - /Users/simamohammadaminifard/.ssh:/home/airflow/.ssh:ro
    - /Users/simamohammadaminifard/dags:/opt/airflow/dags
    - /Users/simamohammadaminifard/data:/opt/airflow/data
    - ${AIRFLOW_PROJ_DIR:-.}/logs:/opt/airflow/logs
    - ${AIRFLOW_PROJ_DIR:-.}/config:/opt/airflow/config
    - ${AIRFLOW_PROJ_DIR:-.}/plugins:/opt/airflow/plugins
  user: "${AIRFLOW_UID:-50000}:0"
  depends_on:
    &airflow-common-depends-on
    redis:
      condition: service_healthy
    postgres:
      condition: service_healthy

services:
  postgres:
    image: postgres:13
    environment:
      POSTGRES_USER: airflow
      POSTGRES_PASSWORD: airflow
      POSTGRES_DB: airflow
    volumes:
      - postgres-db-volume:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD", "pg_isready", "-U", "airflow"]
      interval: 10s
      retries: 5
      start_period: 5s
    restart: always
    networks:
      - airflow_network
      - mlflow-airflow-net

  redis:
    image: redis:7.2-bookworm
    expose:
      - 6379
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 30s
      retries: 50
      start_period: 30s
    restart: always
    networks:
      - airflow_network
      - mlflow-airflow-net

  airflow-webserver:
    <<: *airflow-common
    command: webserver
    ports:
      - "8080:8080"
    healthcheck:
      test: ["CMD", "curl", "--fail", http://localhost:8080/health]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 30s
    restart: always
    depends_on:
      <<: *airflow-common-depends-on
      airflow-init:
        condition: service_completed_successfully
    networks:
      - airflow_network
      - mlflow-airflow-net

  airflow-scheduler:
    <<: *airflow-common
    command: scheduler
    healthcheck:
      test: ["CMD", "curl", "--fail", http://localhost:8974/health]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 30s
    restart: always
    depends_on:
      <<: *airflow-common-depends-on
      airflow-init:
        condition: service_completed_successfully
    networks:
      - airflow_network
      - mlflow-airflow-net

  airflow-worker:
    <<: *airflow-common
    command: celery worker
    healthcheck:
      test:
        - "CMD-SHELL"
        - 'celery --app airflow.providers.celery.executors.celery_executor.app inspect ping -d "celery@$${HOSTNAME}" || celery --app airflow.executors.celery_executor.app inspect ping -d "celery@$${HOSTNAME}"'
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 30s
    environment:
      <<: *airflow-common-env
      DUMB_INIT_SETSID: "0"
    restart: always
    depends_on:
      <<: *airflow-common-depends-on
      airflow-init:
        condition: service_completed_successfully
    networks:
      - airflow_network
      - mlflow-airflow-net

  airflow-triggerer:
    <<: *airflow-common
    command: triggerer
    healthcheck:
      test: ["CMD-SHELL", 'airflow jobs check --job-type TriggererJob --hostname "$${HOSTNAME}"']
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 30s
    restart: always
    depends_on:
      <<: *airflow-common-depends-on
      airflow-init:
        condition: service_completed_successfully
    networks:
      - airflow_network
      - mlflow-airflow-net

  airflow-init:
    <<: *airflow-common
    entrypoint: /bin/bash
    command:
      - -c
      - |
        if [[ -z "${AIRFLOW_UID}" ]]; then
          echo
          echo -e "\033[1;33mWARNING!!!: AIRFLOW_UID not set!\e[0m"
          echo "If you are on Linux, you SHOULD follow the instructions below to set "
          echo "AIRFLOW_UID environment variable, otherwise files will be owned by root."
          echo "For other operating systems you can get rid of the warning with manually created .env file:"
          echo "    See: https://airflow.apache.org/docs/apache-airflow/stable/howto/docker-compose/index.html#setting-the-right-airflow-user"
          echo
        fi
        one_meg=1048576
        mem_available=$$(($$(getconf _PHYS_PAGES) * $$(getconf PAGE_SIZE) / one_meg))
        cpus_available=$$(grep -cE 'cpu[0-9]+' /proc/stat)
        disk_available=$$(df / | tail -1 | awk '{print $$4}')
        warning_resources="false"
        if (( mem_available < 4000 )) ; then
          echo
          echo -e "\033[1;33mWARNING!!!: Not enough memory available for Docker.\e[0m"
          echo "At least 4GB of memory required. You have $$(numfmt --to iec $$((mem_available * one_meg)))"
          echo
          warning_resources="true"
        fi
        if (( cpus_available < 2 )); then
          echo
          echo -e "\033[1;33mWARNING!!!: Not enough CPUS available for Docker.\e[0m"
          echo "At least 2 CPUs recommended. You have $${cpus_available}"
          echo
          warning_resources="true"
        fi
        if (( disk_available < one_meg * 10 )); then
          echo
          echo -e "\033[1;33mWARNING!!!: Not enough Disk space available for Docker.\e[0m"
          echo "At least 10 GBs recommended. You have $$(numfmt --to iec $$((disk_available * 1024 )))"
          echo
          warning_resources="true"
        fi
        if [[ $${warning_resources} == "true" ]]; then
          echo
          echo -e "\033[1;33mWARNING!!!: You have not enough resources to run Airflow (see above)!\e[0m"
          echo "Please follow the instructions to increase amount of resources available:"
          echo "   https://airflow.apache.org/docs/apache-airflow/stable/howto/docker-compose/index.html#before-you-begin"
          echo
        fi
        mkdir -p /sources/logs /sources/dags /sources/plugins
        chown -R "${AIRFLOW_UID}:0" /sources/{logs,dags,plugins}
        exec /entrypoint airflow version
    environment:
      <<: *airflow-common-env
      _AIRFLOW_DB_MIGRATE: 'true'
      _AIRFLOW_WWW_USER_CREATE: 'true'
      _AIRFLOW_WWW_USER_USERNAME: ${_AIRFLOW_WWW_USER_USERNAME:-airflow}
      _AIRFLOW_WWW_USER_PASSWORD: ${_AIRFLOW_WWW_USER_PASSWORD:-airflow}
      _PIP_ADDITIONAL_REQUIREMENTS: ''
    user: "0:0"
    volumes:
      - ${AIRFLOW_PROJ_DIR:-.}:/sources
    networks:
      - airflow_network
      - mlflow-airflow-net

  airflow-cli:
    <<: *airflow-common
    profiles:
      - debug
    environment:
      <<: *airflow-common-env
      CONNECTION_CHECK_MAX_COUNT: "0"
    command:
      - bash
      - -c
      - airflow
    networks:
      - airflow_network
      - mlflow-airflow-net

  flower:
    <<: *airflow-common
    command: celery flower
    profiles:
      - flower
    ports:
      - "5555:5555"
    healthcheck:
      test: ["CMD", "curl", "--fail", http://localhost:5555/]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 30s
    restart: always
    depends_on:
      <<: *airflow-common-depends-on
      airflow-init:
        condition: service_completed_successfully
    networks:
      - airflow_network
      - mlflow-airflow-net

volumes:
  postgres-db-volume:
  mysql_data:

networks:
  airflow_network:
    driver: bridge
  mlflow-airflow-net:
    external: true
```


then we bring the airflow up 
```docker compose -f airflow_ssh.yaml up --build -d```


then inside the mlflow directory

```docker compose -f mlflow.yaml up --build -d```


