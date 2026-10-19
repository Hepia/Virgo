#!/bin/bash

# Variables
DB_NAME="mirai"
DB_USER="root"
DB_PASS="password"
DB_HOST="localhost"

# Function to display the users from the database
display_users_from_db() {
    echo "Fetching and displaying users from the database..."

    # Query to select all users from the database
    QUERY="SELECT id, username, password, duration_limit, cooldown, max_bots, admin, api_key FROM $DB_NAME.users;"

    # Execute the query using MySQL and display the results
    mysql -u $DB_USER -p$DB_PASS -h $DB_HOST -e "$QUERY" $DB_NAME
}

# Call the function to display users
display_users_from_db
