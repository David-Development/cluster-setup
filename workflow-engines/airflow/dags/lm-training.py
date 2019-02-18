from airflow.contrib.operators.kubernetes_pod_operator import KubernetesPodOperator
from airflow.operators.python_operator import PythonOperator
from airflow.operators.bash_operator import BashOperator
from airflow.models import DAG
from datetime import datetime
import time
import os

args = {
    'owner': 'airflow',
    "start_date": datetime(2018, 10, 4),
}

dag = DAG(
    dag_id='test_kubernetes_exec',
    default_args=args,
    schedule_interval=None
)

t1 = BashOperator(
    task_id='test',
    bash_command='date',
    dag=dag)

#k = KubernetesPodOperator(namespace='default',
#                          image="ubuntu:16.04",
#                          cmds=["echo", "was geht ab"],
#                          arguments=["echo", "123 Was geht ab???10"],
#                          labels={"foo": "bar"},
#                          name="test",
#                          task_id="kubernetes_task",
#                          is_delete_operator_pod=True,
#                          hostnetwork=False,
#                          dag=dag
#                          )



#t1 >> k
#t1.set_upstream(k)
