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
    exit 128
  fi
  info "Timezone changed to: $TZ"
else
  info "No timezone given, using default."
fi

# Write cronjob env to file, fill in sensible defaults
info "Writting Cronjob environment variables."
cat <<EOF >env.sh
BACKUP_IDENT="${BACKUP_IDENT:-true}"
BACKUP_SOURCES="${BACKUP_SOURCES:-/backup}"
BACKUP_CRON_EXPRESSION="${BACKUP_CRON_EXPRESSION:-* * * * *}"
AWS_S3_BUCKET_NAME="${AWS_S3_BUCKET_NAME:-}"
BACKUP_FILENAME_TEMPLATE="${BACKUP_FILENAME:-backup-%Y-%m-%dT%H-%M-%S.tar.gz}"
BACKUP_ARCHIVE="${BACKUP_ARCHIVE:-/archive}"
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

# TODO: Check (some) environments vars

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
