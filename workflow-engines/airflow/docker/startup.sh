#!/bin/bash

# https://docs.docker.com/config/containers/multi-service_container/




# initialize the database
airflow initdb


# use Kubernetes-Executor
sed -i 's/executor = SequentialExecutor/executor = KubernetesExecutor/g' /airflow/airflow.cfg
sed -i 's/worker_container_repository =/worker_container_repository = ubuntu/g' /airflow/airflow.cfg
sed -i 's/worker_container_tag =/worker_container_tag = 16.04/g' /airflow/airflow.cfg


# The Postgres connection string
sed -i 's?sql_alchemy_conn = sqlite:////airflow/airflow.db?sql_alchemy_conn = postgresql://airflow:airflow@airflow-db/airflow?g' /airflow/airflow.cfg
sed -i 's?dags_volume_host =?dags_volume_host = /airflow/dags?g' /airflow/airflow.cfg

# use local kube config
sed -i 's?in_cluster = True?in_cluster = False?g' /airflow/airflow.cfg


#cat /airflow/airflow.cfg

sleep 20
echo ""
echo "Reinitializing database now!"

# reinitialize the database
airflow initdb






# setup email!!!


echo "Starting webserver"
# start the web server, default port is 8080
airflow webserver -p 8080 &
status=$?
if [ $status -ne 0 ]; then
  echo "Failed to start my_first_process: $status"
  exit $status
fi

echo "Starting scheduler"

# start the scheduler
airflow scheduler
status=$?
if [ $status -ne 0 ]; then
  echo "Failed to start my_second_process: $status"
  exit $status
fi
