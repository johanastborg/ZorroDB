import pytest
import redis

def test_insert_and_get(redis_client):
    # redis_client.fcall('zorro_insert', 0, 'id1', 10, 20, 'name', 'object1')
    # Note: FCALL keys args. We pass 0 keys.

    try:
        redis_client.fcall('zorro_insert', 0, 'id1', 10, 20, 'name', 'object1')
    except redis.ResponseError as e:
        pytest.fail(f"Insert failed: {e}")

    data = redis_client.fcall('zorro_get', 0, 'id1')
    # HGETALL returns a dict in Python client usually, but FCALL returns list/array from Lua?
    # Lua HGETALL returns list. Python Redis client might parse it if configured?
    # With decode_responses=True, it returns list of strings.

    # We need to verify content.
    # ['x', '10', 'y', '20', 'name', 'object1']
    assert 'x' in data
    assert '10' in data
    assert 'name' in data
    assert 'object1' in data

def test_query_range(redis_client):
    # Insert some points
    points = [
        ('p1', 2, 2),
        ('p2', 5, 5),
        ('p3', 10, 10),
        ('p4', 2, 8),
        ('p5', 8, 2)
    ]

    for pid, x, y in points:
        redis_client.fcall('zorro_insert', 0, pid, x, y)

    # Query box [0,0] to [6,6]
    # Should include p1 (2,2) and p2 (5,5). p3(10,10) is out. p4(2,8) is out (y>6). p5(8,2) is out (x>6).

    results = redis_client.fcall('zorro_query_range', 0, 0, 0, 6, 6)

    assert 'p1' in results
    assert 'p2' in results
    assert 'p3' not in results
    assert 'p4' not in results
    assert 'p5' not in results

def test_morton_encoding_logic(redis_client):
    # We can't directly test local functions inside the library,
    # but we can verify behavior via side effects (inserting and checking ZSET score)

    redis_client.fcall('zorro_insert', 0, 'test_z', 1, 1) # 1=01, 1=01 -> interleaved 11 = 3

    score = redis_client.zscore('zorro:index', 'test_z')
    assert int(score) == 3

    redis_client.fcall('zorro_insert', 0, 'test_z2', 2, 1) # x=2 (10), y=1 (01) -> ...
    # x: 1 0
    # y: 0 1
    # mix: y1 x1 y0 x0 = 0 1 1 0 = 6

    score = redis_client.zscore('zorro:index', 'test_z2')
    assert int(score) == 6
