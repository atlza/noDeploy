#!/bin/bash
set -e

# Environnement argument — doit être assigné en premier
environnement=$1
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "--- Launching deploy as ${ME} in ${environnement} ---"

if [ -z "$environnement" ]; then
    echo "Environnement is missing"
    exit 1
elif [ "$environnement" != 'prod' ] && [ "$environnement" != 'recette' ]; then
    echo "Environnement is wrong, should be prod or recette"
    exit 1
fi

# Loading vars
VARS_FILE="${SCRIPT_DIR}/variables.${environnement}"
if [ ! -f "$VARS_FILE" ]; then
    echo "Error: Environment variables file '${VARS_FILE}' not found."
    echo "Please create 'variables.${environnement}' or check the environment name."
    exit 1
fi
source "$VARS_FILE"

# Define flag file
DB_CREATED_FLAG_FILE="${SCRIPT_DIR}/DB/.db_created"

# Check if DB setup has been run
if [ ! -f "$DB_CREATED_FLAG_FILE" ]; then
    echo "--- Running initial database setup for project: ${PROJECT} ---"
    if "${SCRIPT_DIR}/DB/create.sh" "$PROJECT"; then
        echo "Database setup completed successfully."
        touch "$DB_CREATED_FLAG_FILE"
    else
        echo "Error: Database setup failed. Aborting deployment."
        exit 1
    fi
fi

sudo -i -u "$ME" bash -c "${SCRIPT_DIR}/realDeploy.sh ${environnement} ${SCRIPT_DIR}"
