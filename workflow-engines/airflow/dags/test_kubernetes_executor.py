from airflow.operators.python_operator import PythonOperator
from airflow.models import DAG
from datetime import datetime
import time
import os

args = {
    'owner': 'airflow',
    "start_date": datetime(2018, 10, 4),
}

dag = DAG(
    dag_id='test_kubernetes_executor',
    default_args=args,
    schedule_interval=None
)

def print_stuff():
    print("Hi Airflow")

for i in range(2):
    one_task = PythonOperator(
        task_id="one_task" + str(i),
        python_callable=print_stuff,
        dag=dag
    )

    second_task = PythonOperator(
        task_id="two_task" + str(i),
        python_callable=print_stuff,
        dag=dag
    )

    third_task = PythonOperator(
        task_id="third_task" + str(i),
        python_callable=print_stuff,
        dag=dag
    )

one_task >> second_task >> third_task