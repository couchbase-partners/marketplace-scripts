FROM ubuntu:18.04
RUN apt-get update && apt-get install -y python procps && apt-get clean
COPY . /app
COPY ./test_scripts/docker/systemctl.py /usr/bin/systemctl
RUN chmod +x /usr/bin/systemctl
#RUN test -L /bin/systemctl || ln -sf /usr/bin/systemctl /bin/systemctl
RUN chmod +x /app/build/couchbase_installer.sh

EXPOSE 8091
CMD [ "/usr/bin/systemctl" ]
ENTRYPOINT [ "/app/build/couchbase_installer.sh" ]