to install jenkinz that sees mlflow and airflow 

```
services:
  jenkins:
    build: .
    container_name: jenkins
    user: root
    ports:
      - "8090:8080"
      - "50000:50000"
    volumes:
      - jenkins_home:/var/jenkins_home
      - /var/run/docker.sock:/var/run/docker.sock
      - /Users/simamohammadaminifard/data:/mlflow/artifacts
      - /Users/simamohammadaminifard/dags:/opt/airflow/dags
      - /Users/simamohammadaminifard/data/jenkinz_project:/myproject
    networks:
      - mlflow-airflow-net
    restart: always

volumes:
  jenkins_home:

networks:
  mlflow-airflow-net:
    external: true


```


then we go to this address: localhost:8090


then in the terminal we put ` docker logs jenkins`
then we copy and paste the password for initializing



make  a `Dockerfile`
```
FROM jenkins/jenkins:lts

USER root

# Install Python and Docker CLI (optional but helpful)
RUN apt-get update && \
    apt-get install -y python3 python3-pip docker.io && \
    usermod -aG docker jenkins

USER jenkins
```


```
docker compose -f jenkinz.ymal up --build -d
```




inside the build section of shell :
```
cd /myproject

# ساخت venv (اگر برای اولین بار اجرا می‌کنی)
python3 -m venv .venv

# فعال‌سازی
. .venv/bin/activate

# نصب پکیج‌ها
pip install -r requirements.txt

# اجرای کد
python train.py
```


in our train.py file we have:
```
import mlflow
import mlflow.sklearn
import pandas as pd
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score

# --- خواندن دیتا از دیتابیس یا فایل CSV ---
# اگر می‌خوای از دیتابیس بخونی باید sqlalchemy و pymysql هم نصب باشه
import sqlalchemy

engine = sqlalchemy.create_engine('mysql+pymysql://root:mypass@host.docker.internal:3306/simadb')
query = "SELECT * FROM previous_run_15_0_ WHERE Buyer=1"
df = pd.read_sql(query, engine)

if df.empty:
    print("do not run if the dataframe is empty")
    exit()

feature_cols = [
    'location_longitude',
    'location_latitude',
    'name_type',
    'url_type',
    'visit_level_custom_var_v1'
]
for col in feature_cols:
    if col not in df.columns:
        print(f"this column does not exist {col}.")
        exit()
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
```

in our requirements.txt we have 
```
mlflow
scikit-learn
pandas
sqlalchemy
pymysql
```


in our predict.py we have

```
import mlflow
import mlflow.sklearn
import pandas as pd

mlflow.set_tracking_uri("http://mlflow:5000")
experiment_name = "worker_All_in_one_15_0_-predict-versioning"
experiment = mlflow.get_experiment_by_name(experiment_name)
runs = mlflow.search_runs([experiment.experiment_id])

if "metrics.accuracy" not in runs.columns or runs["metrics.accuracy"].dropna().empty:
    print("هیچ ران با متریک accuracy وجود ندارد! اول یک مدل ثبت کن.")
    exit()

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
```

in the build section for prediction in jenkins in the shell section we type:

