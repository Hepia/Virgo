#!/bin/bash

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

# Function to install MySQL if not already installed
install_mysql() {
    echo "Checking MySQL installation..."
    if ! command -v mysql &> /dev/null; then
        echo "MySQL is not installed. Installing MySQL..."

        # Update packages
        sudo apt update

        # Install MySQL
        sudo apt install -y default-mysql-server

        # Start MySQL service
        sudo systemctl start mysql
        sudo systemctl enable mysql

        echo "MySQL installed and started."
    else
        echo "MySQL is already installed."
    fi
}

# Function to set the root password for MariaDB/MySQL
configure_root_password() {
    echo "Configuring MySQL root password..."
    sudo mysql <<EOF
SET PASSWORD FOR 'root'@'localhost' = PASSWORD('$DB_PASS');
FLUSH PRIVILEGES;
EOF
    echo "Root password set successfully."
}

# Function to create the database and tables
create_db_and_tables() {
    echo "Creating the database and tables..."

    if ! sudo systemctl is-active --quiet mysql; then
        echo "MySQL is not running. Please start MySQL first."
        exit 1
    fi

    sudo mysql -u $DB_USER -p$DB_PASS -h $DB_HOST < "$SQL_FILE"

    if [ $? -eq 0 ]; then
        echo "Database and tables created successfully."
    else
        echo "Error occurred while creating the database or tables."
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

        sudo mysql -u $DB_USER -p$DB_PASS -h $DB_HOST -e "INSERT INTO $DB_NAME.users (username, password, duration_limit, cooldown, max_bots, admin, last_paid, api_key) VALUES ('$username', '$password', $duration_limit, $cooldown, $max_bots, $admin, UNIX_TIMESTAMP(), '$api_key');"

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
create_db_and_tables
insert_data_from_json

echo "All tasks completed!"
