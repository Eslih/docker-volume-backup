#!/bin/sh

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

# Check timezone
if [ -n "$TZ" ]; then
  if [ ! -f "/usr/share/zoneinfo/$TZ" ]; then
    error "Invalid / Unknown timezone: $TZ"
    exit 1
  fi
  info "Timezone changed to: $TZ"
else
  info "No timezone given, using default."
fi

# Write cronjob env to file, fill in sensible defaults
info "Writting Cronjob environment variables."
cat <<EOF >env.sh
BACKUP_SOURCE_PATH="${BACKUP_SOURCE_PATH:-/backup}"
BACKUP_CRON_EXPRESSION="${BACKUP_CRON_EXPRESSION:-30 3 * * *}"
AWS_S3_BUCKET_NAME="${AWS_S3_BUCKET_NAME:-}"
BACKUP_FILENAME_TEMPLATE="${BACKUP_FILENAME:-backup-%Y-%m-%dT%H-%M-%S.tar.gz}"
BACKUP_ARCHIVE="${BACKUP_ARCHIVE:-true}"
BACKUP_ARCHIVE_PATH="${BACKUP_ARCHIVE_PATH:-/archive}"
BACKUP_WAIT_SECONDS="${BACKUP_WAIT_SECONDS:-0}"
BACKUP_HOSTNAME="${BACKUP_HOSTNAME:-$(hostname)}"
INFLUXDB_URL="${INFLUXDB_URL:-}"
INFLUXDB_DB="${INFLUXDB_DB:-}"
INFLUXDB_CREDENTIALS="${INFLUXDB_CREDENTIALS:-}"
INFLUXDB_MEASUREMENT="${INFLUXDB_MEASUREMENT:-docker_volume_backup}"
EOF

chmod a+x env.sh

# Read cronjob env files
. env.sh

# TODO: Check (some more) environments vars

# Does the backup source exists?
if [ ! -d "$BACKUP_SOURCE_PATH" ]; then
  error "The backup source path ($BACKUP_SOURCE_PATH [\"$BACKUP_SOURCE_PATH\"]) is not  valid."
  exit 1
  if [ -z "$(ls -A "$BACKUP_SOURCE_PATH")" ]; then
    error "The backup source doesn't contain any files. Did you provide the right path / mounting point?"
    exit 1
  fi
fi

# If BACKUP_ARCHIVE is true, check BACKUP_ARCHIVE is a valid, writable directory
if [ "$BACKUP_ARCHIVE" = "true" ]; then
  if [ ! -d "$BACKUP_ARCHIVE_PATH" ]; then
    error "The backup archive path (\$BACKUP_ARCHIVE_PATH [$BACKUP_ARCHIVE_PATH]) is not valid."
    exit 1
  elif [ ! -w "$BACKUP_ARCHIVE_PATH" ]; then
    error "The backup archive path (\$BACKUP_ARCHIVE_PATH [$BACKUP_ARCHIVE_PATH]) is not writable."
    exit 1
  fi
else
  echo "\"$BACKUP_ARCHIVE\" is not true, tarball will only be saved inside the container."
fi

# Add our cron entry, and direct stdout & stderr to Docker commands stdout
info "Adding cronjob to /etc/crontabs/root"
echo "$BACKUP_CRON_EXPRESSION /root/backup.sh > /proc/1/fd/1 2>&1" >/etc/crontabs/root

info "Entrypoint finished... Execute CMD."

exec "$@"

# TODO
# Exit immediately on error
#set -e
#
## Configure AWS CLI
#mkdir -p .aws
#cat <<EOF >.aws/credentials
#[default]
#aws_access_key_id = ${AWS_ACCESS_KEY_ID}
#aws_secret_access_key = ${AWS_SECRET_ACCESS_KEY}
#EOF
#if [ ! -z "$AWS_DEFAULT_REGION" ]; then
#  cat <<EOF >.aws/config
#[default]
#region = ${AWS_DEFAULT_REGION}
#EOF
#fi
#
