FROM alpine:3.10.3

RUN apk add --no-cache docker openrc tzdata gnupg
RUN rc-update add docker boot

WORKDIR /root
COPY ./src/entrypoint.sh ./src/backup.sh ./

RUN chmod a+x entrypoint.sh backup.sh

ENTRYPOINT ["./entrypoint.sh"]

CMD ["crond", "-l", "8",  "-f"]

# docker run -it -e TZ="Europe/Brussels" -v /var/run/docker.sock:/var/run/docker.sock:ro eslih/docker-volume-backup sh