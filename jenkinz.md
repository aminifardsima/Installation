to install jenkinz that sees mlflow and airflow 

```
services:
  jenkins:
    image: jenkins/jenkins:lts
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
