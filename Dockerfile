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
