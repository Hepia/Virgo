#!/bin/bash
set -euo pipefail

# Variables
#REPO_DIR="$(pwd)"  # Project directory, assuming the script is in this directory
REPO_DIR="/etc/mirai/db"
DB_NAME="mirai"
DB_USER="root"
DB_PASS="password"
DB_HOST="127.0.0.1"

# SQL and JSON file paths
SQL_FILE="$REPO_DIR/db.sql"
JSON_FILE="$REPO_DIR/users.json"

# Use sudo only when not already root (containers usually run as root and lack sudo)
if [ "$(id -u)" -eq 0 ]; then
    SUDO=""
else
    SUDO="sudo"
fi

export DEBIAN_FRONTEND=noninteractive

# Start the database service, with or without systemd
start_mysql() {
    if command -v systemctl &> /dev/null && [ -d /run/systemd/system ]; then
        $SUDO systemctl start mariadb 2>/dev/null || $SUDO systemctl start mysql
        $SUDO systemctl enable mariadb 2>/dev/null || $SUDO systemctl enable mysql
    elif command -v service &> /dev/null && [ -x /etc/init.d/mariadb ]; then
        $SUDO service mariadb start
    else
        # No init system at all (e.g. plain docker container): start the daemon directly
        $SUDO install -d -o mysql -g mysql /run/mysqld
        $SUDO bash -c 'nohup mysqld_safe > /var/log/mysqld_safe.log 2>&1 &'
    fi

    echo "Waiting for the database to accept connections..."
    for i in $(seq 1 30); do
        if $SUDO mysqladmin ping --silent 2>/dev/null; then
            return 0
        fi
        sleep 1
    done
    echo "ERROR: database did not start within 30 seconds" >&2
    return 1
}

# Function to install MySQL if not already installed
install_mysql() {
    echo "Checking MySQL installation..."
    if ! command -v mysql &> /dev/null; then
        echo "MySQL is not installed. Installing MySQL..."

        # Update packages
        $SUDO apt-get update

        # Install MySQL (MariaDB on Debian)
        $SUDO apt-get install -y default-mysql-server

        echo "MySQL installed."
    else
        echo "MySQL is already installed."
    fi

    # Make sure the server is running
    if ! $SUDO mysqladmin ping --silent 2>/dev/null; then
        start_mysql
    fi
    echo "MySQL is running."
}

# Function to set the root password for MariaDB/MySQL
configure_root_password() {
    echo "Configuring MySQL root password..."
    # MariaDB: keep passwordless unix-socket login for the local root OS user
    # (used by Debian maintenance scripts) and add a password for TCP logins.
    # Fallback: plain ALTER USER for MySQL, which lacks the OR syntax.
    $SUDO mysql <<SQL || $SUDO mysql <<SQL2
ALTER USER 'root'@'localhost' IDENTIFIED VIA unix_socket OR mysql_native_password USING PASSWORD('$DB_PASS');
FLUSH PRIVILEGES;
SQL
ALTER USER 'root'@'localhost' IDENTIFIED BY '$DB_PASS';
FLUSH PRIVILEGES;
SQL2
    echo "Root password set successfully."
}

# Verify that the configured credentials work over TCP
verify_login() {
    echo "Verifying login as $DB_USER@$DB_HOST..."
    mysql -u "$DB_USER" -p"$DB_PASS" -h "$DB_HOST" -e 'SELECT VERSION();'
}

create_db_and_tables() {
    echo "Creating the database and tables..."

    if [ ! -f "$SQL_FILE" ]; then
        echo "ERROR: SQL file not found: $SQL_FILE" >&2
        exit 1
    fi

    # Ask the server directly instead of systemctl: a plain Debian container
    # has no systemd, so "systemctl is-active" always fails there.
    if ! mysqladmin ping -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" --silent >/dev/null 2>&1; then
        echo "MySQL is not running. Please start MySQL first." >&2
        exit 1
    fi

    # With "set -e" a failing command aborts the script before "$?" can be
    # inspected, so test the command itself in the if.
    if mysql -u "$DB_USER" -p"$DB_PASS" -h "$DB_HOST" < "$SQL_FILE"; then
        echo "Database and tables created successfully."
    else
        echo "Error occurred while creating the database or tables." >&2
        exit 1
    fi
}


# Function to insert data from the JSON file
insert_data_from_json() {
    echo "Inserting data from the JSON file..."

    if [ ! -f "$JSON_FILE" ]; then
        echo "The JSON file $JSON_FILE does not exist. Please make sure the file is in the directory."
        exit 1
    fi

    USERS=$(cat "$JSON_FILE")

    for USER in $(echo "$USERS" | jq -r '.users[] | @base64'); do
        _jq() {
            echo ${USER} | base64 --decode | jq -r ${1}
        }

        username=$(_jq '.username')
        password=$(_jq '.password')
        duration_limit=$(_jq '.duration_limit')
        cooldown=$(_jq '.cooldown')
        max_bots=$(_jq '.max_bots')
        admin=$(_jq '.admin')
        api_key=$(_jq '.api_key')

        $SUDO mysql -u $DB_USER -p$DB_PASS -h $DB_HOST -e "INSERT INTO $DB_NAME.users (username, password, duration_limit, cooldown, max_bots, admin, last_paid, api_key) VALUES ('$username', '$password', $duration_limit, $cooldown, $max_bots, $admin, UNIX_TIMESTAMP(), '$api_key');"

        if [ $? -eq 0 ]; then
            echo "User $username inserted successfully."
        else
            echo "Error inserting user $username."
        fi
    done
}


# Main script flow
install_mysql
configure_root_password
verify_login
create_db_and_tables
insert_data_from_json

echo "All tasks completed!"
