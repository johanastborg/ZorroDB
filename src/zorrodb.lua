#!lua name=zorrodb

-- Morton Code (Z-order curve) implementation for 2D coordinates
-- Based on bit interleaving

local function part1by1(n)
  n = bit.band(n, 0x0000ffff)
  n = bit.band(bit.bor(n, bit.lshift(n, 8)), 0x00FF00FF)
  n = bit.band(bit.bor(n, bit.lshift(n, 4)), 0x0F0F0F0F)
  n = bit.band(bit.bor(n, bit.lshift(n, 2)), 0x33333333)
  n = bit.band(bit.bor(n, bit.lshift(n, 1)), 0x55555555)
  return n
end

local function morton_encode(x, y)
  return bit.bor(part1by1(x), bit.lshift(part1by1(y), 1))
end

-- Data storage
-- Hash: zorro:data:<id> -> { x: x, y: y, ...data }
-- ZSet: zorro:index -> score: morton_code, member: <id>

local function insert(keys, args)
  -- args: id, x, y, key1, val1, key2, val2 ...
  if #args < 3 then
    return redis.error_reply("Usage: zorro_insert id x y [key val ...]")
  end

  local id = args[1]
  local x = tonumber(args[2])
  local y = tonumber(args[3])

  if not x or not y then
    return redis.error_reply("x and y must be numbers")
  end

  local z_code = morton_encode(x, y)

  -- Store data
  local data_key = "zorro:data:" .. id
  local hash_args = { "x", x, "y", y }
  for i = 4, #args do
    table.insert(hash_args, args[i])
  end
  redis.call("HSET", data_key, unpack(hash_args))

  -- Update index
  redis.call("ZADD", "zorro:index", z_code, id)

  return "OK"
end

local function get(keys, args)
    local id = args[1]
    if not id then
        return redis.error_reply("Usage: zorro_get id")
    end
    local data_key = "zorro:data:" .. id
    return redis.call("HGETALL", data_key)
end


-- Range Query
-- This is a naive implementation that calculates the Z-range min and max
-- and fetches everything in between, then filters.
-- A better implementation would compute multiple Z-intervals.

local function query_range(keys, args)
  -- args: x_min, y_min, x_max, y_max
  if #args < 4 then
    return redis.error_reply("Usage: zorro_query_range x_min y_min x_max y_max")
  end

  local x_min = tonumber(args[1])
  local y_min = tonumber(args[2])
  local x_max = tonumber(args[3])
  local y_max = tonumber(args[4])

  -- Calculate the Morton code range
  local z_min = morton_encode(x_min, y_min)
  local z_max = morton_encode(x_max, y_max)

  -- Retrieve candidates from ZSET
  local candidates = redis.call("ZRANGE", "zorro:index", z_min, z_max, "BYSCORE")

  local results = {}

  for _, id in ipairs(candidates) do
    local data_key = "zorro:data:" .. id
    local point_x = tonumber(redis.call("HGET", data_key, "x"))
    local point_y = tonumber(redis.call("HGET", data_key, "y"))

    if point_x and point_y then
      if point_x >= x_min and point_x <= x_max and point_y >= y_min and point_y <= y_max then
        table.insert(results, id)
      end
    end
  end

  return results
end

redis.register_function{
  function_name = 'zorro_insert',
  callback = insert,
  flags = {}
}

redis.register_function{
  function_name = 'zorro_get',
  callback = get,
  flags = { 'no-writes' }
}

redis.register_function{
  function_name = 'zorro_query_range',
  callback = query_range,
  flags = { 'no-writes' }
}
