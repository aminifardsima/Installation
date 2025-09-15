# Apache Airflow Setup using Docker Compose

This guide helps you set up Apache Airflow using a Docker Compose configuration file (`airflow_ssh.yaml`).

## Getting Started
### make sure your docker hub is runing and give adequate ram to it.

### Step 1: Navigate to Your Airflow Directory

Open your terminal and go to the path where you have placed the `airflow_ssh.yaml` file:

```
cd /path/to/your/airflow/project
```

### step2: run this in your terminals

```
docker-compose -f airflow_ssh.yaml up --build -d     ‍‍‍
```

### If everything goes wrong then run this command:

```
docker-compose -f airflow_ssh.yaml down
```

### Then you can make the Airflow runing on your docker by repeating the step 1 and Step 2:
### Have Fun!



```
docker compose -f airflow_ssh.yaml down --volumes --remove-orphans
```

helpful commands:

```
docker compose -f airflow_ssh.yaml up --build airflow-init
```


```
 docker compose -f airflow_ssh.yaml --build -d up airflow-init
```

```
docker compose -f airflow_ssh.yaml up --build -d
```



