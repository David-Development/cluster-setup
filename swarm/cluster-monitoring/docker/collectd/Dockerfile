FROM alpine

RUN apk add collectd \
            collectd-python \
            collectd-write_http \
            collectd-disk \
            collectd-network

COPY collectd.conf /etc/collectd.conf


### NEW
#RUN apk add python git py-pip
#WORKDIR /usr/share/collectd/
#RUN    git clone https://github.com/David-Development/docker-collectd-plugin.git \
#    && cd docker-collectd-plugin \
#    && pip install -r requirements.txt
#COPY collectd.swarm.conf /etc/collectd.conf
### NEW


COPY run.sh run.sh
RUN chmod +x run.sh

ENTRYPOINT [ "./run.sh" ]

