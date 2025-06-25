# Apache Airflow Setup using Docker Compose

This guide helps you set up Apache Airflow using a Docker Compose configuration file (`airflow_ssh.yaml`).

## Getting Started
### make sure your docker hub is runing and give adequate ram to it.

### Step 1: Navigate to Your Airflow Directory

Open your terminal and go to the path where you have placed the `airflow_ssh.yaml` file:

```bash
cd /path/to/your/airflow/project
```

### step2: run this in your terminals
```bash
docker-compose -f airflow_ssh.yaml up --build -d     ‍‍‍
```

### If everything goes wrong then run this command:
```bash
docker-compose -f airflow_ssh.yaml down
```

### Then you can make the Airflow runing on your docker by repeating the step 1 and Step 2:
### Have Fun!



