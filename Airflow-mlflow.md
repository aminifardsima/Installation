mlflow with airflow on seperate docker file.
```
docker network create mlflow-airflow-net
```
create ```mlflow.yaml``` file

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
then in the same folder that we have made our mlflow.yaml file we make a file we name it `Dockerfile` then we put this information in it:



```
FROM ghcr.io/mlflow/mlflow:latest

RUN pip install pymysql

```



Then we make `airflow_ssh.yaml` file


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
    - /Users/simamohammadaminifard/data:/mlflow/artifacts
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
then in the same folder we have made our airflow.yaml we make a file we name it `Dockerfile` 


```
FROM apache/airflow:2.10.5

USER root

RUN apt-get update && \
    apt-get install -y \
        openssh-client \
        rsync \
        iputils-ping \
        curl \
        vim && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN mkdir -p /root/.ssh && \
    echo -e "Host *\n  StrictHostKeyChecking no\n  UserKnownHostsFile=/dev/null" > /root/.ssh/config && \
    chmod 600 /root/.ssh/config


USER airflow

```

If you want to install pandas and sqlalchamy in the airflow `Dockerfile` is:
```
FROM apache/airflow:2.10.5

USER root

RUN apt-get update && \
    apt-get install -y \
        openssh-client \
        rsync \
        iputils-ping \
        curl \
        vim && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN mkdir -p /root/.ssh && \
    echo -e "Host *\n  StrictHostKeyChecking no\n  UserKnownHostsFile=/dev/null" > /root/.ssh/config && \
    chmod 600 /root/.ssh/config

USER airflow

RUN pip install --no-cache-dir \
    pymysql \
    sqlalchemy \
    mlflow \
    tensorflow \
    scikit-learn \
    pandas
```



then we bring the airflow up 
```docker compose -f airflow_ssh.yaml up --build -d```


then inside the mlflow directory

```docker compose -f mlflow.yaml up --build -d```




now we write a training machinelearning code. in our code we have:
```


from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.hooks.mysql_hook import MySqlHook
from datetime import datetime
import pandas as pd
import mlflow
import mlflow.sklearn
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score

def train_and_log_model():
    hook = MySqlHook(mysql_conn_id='mysqinternal')
    conn = hook.get_conn()
    query = "SELECT * FROM worker_All_in_one_15_0_ WHERE Buyer=1"
    df = pd.read_sql(query, conn)

    if df.empty:
        print("do not run if the dataframe is empty")
        return

    feature_cols = [
        'location_longitude',
        'location_latitude',
        'name_type',
        'url_type',
        'visit_level_custom_var_v1'
    ]

    for col in feature_cols:
        if col not in df.columns:
            print(f"this column does not exist {col} .")
            return
        if df[col].dtype == 'object':
            df[col] = pd.factorize(df[col])[0]

    X = df[feature_cols].fillna(0)
    y = df['Buyer'].fillna(0)

    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)
    model = RandomForestClassifier(n_estimators=100, random_state=42)
    model.fit(X_train, y_train)
    pred = model.predict(X_test)
    acc = accuracy_score(y_test, pred)

    mlflow.set_tracking_uri("http://mlflow:5000")
    experiment_name = "worker_All_in_one_15_0_-predict-versioning"
    mlflow.set_experiment(experiment_name)
    experiment = mlflow.get_experiment_by_name(experiment_name)
    runs = mlflow.search_runs([experiment.experiment_id])

    existing_versions = []
    if "tags.mlflow.runName" in runs.columns:
        existing_versions = [
            int(str(x).split("_V")[-1])
            for x in runs["tags.mlflow.runName"].dropna()
            if "_V" in str(x) and str(x).split("_V")[-1].isdigit()
        ]
    next_version = max(existing_versions) + 1 if existing_versions else 1
    run_name = f"modelname_V{next_version}"

    with mlflow.start_run(run_name=run_name) as run:
        mlflow.log_param("model_type", "RandomForestClassifier")
        mlflow.log_metric("accuracy", acc)
        mlflow.set_tag("data_source", "mysql_esm_table")
        mlflow.set_tag("feature_set", "v1")
        mlflow.set_tag("model_version", next_version)
        mlflow.sklearn.log_model(model, "model")
        print("Run Name:", run_name)
        print("Run ID:", run.info.run_id)
        print("Accuracy:", acc)

default_args = {
    "owner": "sima",
    "start_date": datetime(2023, 1, 1),
}

with DAG(
    "mlflow_train",
    default_args=default_args,
    schedule_interval=None,
    catchup=False,
    tags=["mysql", "mlflow", "buyer-model"],
) as dag:
    train_and_log = PythonOperator(
        task_id="train_and_log_buyer_model",
        python_callable=train_and_log_model,
    )
```




in our prediction we have:
```
from airflow import DAG
from airflow.operators.python import PythonOperator
from datetime import datetime
import mlflow
import pandas as pd
import mlflow.sklearn

def load_best_model_and_predict():
    mlflow.set_tracking_uri("http://mlflow:5000")
    experiment_name = "worker_All_in_one_15_0_-predict-versioning"
    experiment = mlflow.get_experiment_by_name(experiment_name)
    runs = mlflow.search_runs([experiment.experiment_id])

    print("ستون‌های دیتافریم:", runs.columns)
    print("۵ نمونه اول دیتافریم:", runs.head())

    if "metrics.accuracy" not in runs.columns or runs["metrics.accuracy"].dropna().empty:
        print("هیچ ران با متریک accuracy وجود ندارد! اول یک مدل ثبت کن.")
        return

    best_run = runs.sort_values(by="metrics.accuracy", ascending=False).iloc[0]
    best_run_id = best_run.run_id
    run_name = best_run.get("tags.mlflow.runName", "N/A")
    model_version = best_run.get("tags.model_version", "N/A")
    print(f"Best Run ID: {best_run_id}")
    print(f"Best Run Name (Model Version): {run_name}")
    print(f"Model Version (as tag): {model_version}")
    print(f"Accuracy: {best_run['metrics.accuracy']}")

    # پارامترهای مدل برتر را چاپ کن
    params = {k.replace('params.', ''): v for k, v in best_run.items() if k.startswith('params.')}
    print("پارامترهای مدل برتر:")
    for k, v in params.items():
        print(f"{k}: {v}")

    model_uri = f"runs:/{best_run_id}/model"
    model = mlflow.sklearn.load_model(model_uri)

    # داده تست نمونه (می‌تونی اینجا دیتا را از دیتابیس یا هر جایی بگیری)
    data = {
        'location_longitude': [52.1, 51.4, 50.8, 53.2, 52.7],
        'location_latitude': [35.7, 36.1, 35.8, 35.9, 36.2],
        'name_type': [1, 2, 1, 3, 2],
        'url_type': [2, 1, 2, 3, 2],
        'visit_level_custom_var_v1': [0, 5, 2, 1, 3],
    }
    df_new = pd.DataFrame(data)

    prediction = model.predict(df_new)
    print("پیش‌بینی مدل برتر روی داده جدید:", prediction)

default_args = {
    "owner": "sima",
    "start_date": datetime(2023, 1, 1),
}

with DAG(
    "mlflow_predict",
    default_args=default_args,
    schedule_interval=None,
    catchup=False,
    tags=["mlflow", "predict", "buyer-model"],
) as dag:

    predict_best = PythonOperator(
        task_id="load_and_predict_best_model",
        python_callable=load_best_model_and_predict,
    )
```


