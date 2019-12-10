#!/bin/sh

# TODO: Check errors
# eg. if ! docker ... then ... fi

# TODO: Catch sigterm

error() {
  bold="\033[1m"
  red="\033[31m"
  reset="\033[0m"

  printf "%b\n" "${red}${bold}[ERROR] ${*}${reset}" >&2
}

info() {
  bold="\033[1m"
  reset="\033[0m"

  printf "%b\n" "${bold}[INFO] ${1}${reset}"
}

info "Running backup script..."

# Read cronjob env files
printf "%s\n" "Reading env vars"
. env.sh

# Calculate backup time
time_started="$(date +%s.%N)"

# Default sock file
docker_sock="/var/run/docker.sock"

# -S check if file exists and wheter it is a valid socket
if [ -S "$docker_sock" ]; then
  info "Docker socket passed. Should be able to interact with other containers"

  # Make a "helper" file
  temp_file="$(mktemp)"

  total_containers="$(docker ps --format "{{.ID}}" | wc -l)"
  info "$total_containers container(s) running on host"

  # Run a command before the backup starts
  docker ps \
    --filter "label=docker-volume-backup.exec-pre-backup" \
    --format '{{.ID}} {{.Label "docker-volume-backup.exec-pre-backup"}}' \
    >"$temp_file"
  containers_to_pre_exec_count="$(wc <"$temp_file" -l)"

  info "$containers_to_pre_exec_count container(s) marked to run a pre-exec command"
  while read -r line; do
    printf "Pre-exec command: %s\n" "$line"
    # shellcheck disable=SC2086
    docker exec $line
  done <"$temp_file"

  # Stop containers if needed
  containers_to_stop=$(docker ps \
    --format "{{.ID}}" \
    --filter "label=docker-volume-backup.stop-during-backup=true")
  container_to_stop_count="$(echo "$containers_to_stop" | wc -w)"

  info "$container_to_stop_count container(s) marked to stop during backup"
  for container_id in $containers_to_stop; do
    printf "%s\n" "$container_id"
    docker stop "$container_id"
  done

else
  info "Cannot access \"$docker_sock\", won't interact with the container(s)"
fi

# TODO: Backup!

#
if [ -S "$docker_sock" ]; then

  info "Restarting $container_to_stop_count container(s) ..."
  for container_id in $containers_to_stop; do
    printf "%s\n" "$container_id"
    docker start "$container_id"
  done

  # Run a command after the backup is finished
  docker ps \
    --filter "label=docker-volume-backup.exec-post-backup" \
    --format '{{.ID}} {{.Label "docker-volume-backup.exec-post-backup"}}' \
    >"$temp_file"
  containers_to_post_exec_count="$(wc <"$temp_file" -l)"

  info "$containers_to_post_exec_count container(s) marked to run a post-exec command"
  while read -r line; do
    printf "Post-exec command: %s\n" "$line"
    # shellcheck disable=SC2086
    docker exec $line
  done <"$temp_file"
fi

info "Creating backup"

backup_filename=$(date +"$BACKUP_FILENAME_TEMPLATE")
#time_backup_started="$(date +%s.%N)"
# shellcheck disable=SC2086
if ! tar -czf "$backup_filename" $BACKUP_SOURCE_PATH; then
  error "The script wasn't able to create a tarball! Continuing ..."
fi

#backup_size="$(du -k "$backup_filename" | sed 's/\s.*$//')"
#time_backup_stopped="$(date +%s.%N)"

info "Waiting before processing"
echo "Sleeping $BACKUP_WAIT_SECONDS seconds..."
sleep "$BACKUP_WAIT_SECONDS"

if [ "$BACKUP_ARCHIVE" = "true" ]; then
  info "Archiving backup"
  if ! mv -v "$backup_filename" "$BACKUP_ARCHIVE_PATH/$backup_filename"; then
    error "Not able to arhive the tarball outside the container! Continuing ..."
  fi
fi

info "Backup finished"
echo "Will wait for next scheduled backup"

#
#
#
# TODO
#
#info "Creating backup"
#BACKUP_FILENAME=$(date +"$BACKUP_FILENAME_TEMPLATE")
#TIME_BACK_UP="$(date +%s.%N)"
#tar -czf "$BACKUP_FILENAME" / $BACKUP_SOURCE # allow the var to expand, in case we have multiple sources
#BACKUP_SIZE="$(du --bytes $BACKUP_FILENAME | sed 's/\s.*$//')"
#TIME_BACKED_UP="$(date +%s.%N)"
#
#info "Waiting before processing"
#echo "Sleeping $BACKUP_WAIT_SECONDS seconds..."
#sleep "$BACKUP_WAIT_SECONDS"
#
#TIME_UPLOAD="0"
#TIME_UPLOADED="0"
#if [ ! -z "$AWS_S3_BUCKET_NAME" ]; then
#  info "Uploading backup to S3"
#  echo "Will upload to bucket \"$AWS_S3_BUCKET_NAME\""
#  TIME_UPLOAD="$(date +%s.%N)"
#  aws s3 cp --only-show-errors "$BACKUP_FILENAME" "s3://$AWS_S3_BUCKET_NAME/"
#  echo "Upload finished"
#  TIME_UPLOADED="$(date +%s.%N)"
#fi
#
#
#info "Collecting metrics"
#TIME_FINISH="$(date +%s.%N)"
#INFLUX_LINE="$INFLUXDB_MEASUREMENT\
#,host=$BACKUP_HOSTNAME\
#\
# size_compressed_bytes=$BACKUP_SIZE\
#,containers_total=$CONTAINERS_TOTAL\
#,containers_stopped=$CONTAINERS_TO_STOP_TOTAL\
#,time_wall=$(perl -E "say $TIME_FINISH - $time_started")\
#,time_total=$(perl -E "say $TIME_FINISH - $time_started - $BACKUP_WAIT_SECONDS")\
#,time_compress=$(perl -E "say $TIME_BACKED_UP - $TIME_BACK_UP")\
#,time_upload=$(perl -E "say $TIME_UPLOADED - $TIME_UPLOAD")\
#"
#echo "$INFLUX_LINE" | sed 's/ /,/g' | tr , '\n'
#
#if [ ! -z "$INFLUXDB_URL" ]; then
#  info "Shipping metrics"
#  curl \
#  --silent \
#  --include \
#  --request POST \
#  --user "$INFLUXDB_CREDENTIALS" \
#  "$INFLUXDB_URL/write?db=$INFLUXDB_DB" \
#  --data-binary "$INFLUX_LINE"
#fi
#
