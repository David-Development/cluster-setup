FROM python:3

# airflow needs a home, airflow is the default,
# but you can lay foundation somewhere else if you prefer
# (optional)
ENV AIRFLOW_HOME=/airflow

# install without GPL
# ENV SLUGIFY_USES_TEXT_UNIDECODE=yes

# install using GPL
ENV AIRFLOW_GPL_UNIDECODE=true

RUN pip install --upgrade pip

# install from pypi using pip
RUN pip install apache-airflow[kubernetes]
RUN pip install tenacity==5.0.2
RUN pip install psycopg2-binary

COPY startup.sh startup.sh

ENTRYPOINT ["bash", "./startup.sh"]