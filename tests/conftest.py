import pytest
import redis
import os

@pytest.fixture(scope="session")
def redis_client():
    host = os.environ.get("REDIS_HOST", "localhost")
    port = int(os.environ.get("REDIS_PORT", 6379))
    client = redis.Redis(host=host, port=port, decode_responses=True)

    # Check connection
    try:
        client.ping()
    except redis.ConnectionError:
        pytest.skip("Redis is not available")

    # Load Lua scripts
    # In a real environment we might want to ensure scripts are loaded
    # For now, we assume the test runner will load them or we load them here

    with open("src/zorrodb.lua", "r") as f:
        script = f.read()
        try:
            client.function_load(script, replace=True)
        except redis.ResponseError as e:
            print(f"Failed to load library: {e}")
            # It might already exist or conflict, usually REPLACE=True handles it.
            # If function support is missing (old redis), this will fail.

    yield client

    # Cleanup?
    # client.flushdb()
