#!/bin/bash
host="${REDIS_HOST:-localhost}"
port="${REDIS_PORT:-6379}"

# Read the Lua file
script=$(cat src/zorrodb.lua)

# Use redis-cli to load the function
# We use REPLACE to overwrite if it exists
echo "Loading ZorroDB library..."
cat src/zorrodb.lua | redis-cli -h "$host" -p "$port" -x FUNCTION LOAD REPLACE

if [ $? -eq 0 ]; then
  echo "Successfully loaded."
else
  echo "Failed to load library."
  exit 1
fi
