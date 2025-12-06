# ZorroDB

ZorroDB is a database built on top of Redis using Lua stored functions. It leverages Morton codes (Z-order curve) to support multi-dimensional queries (range and select) using only key-value and Redis native data structures.

## Features

- **Multi-dimensional Range Queries**: Efficiently query data within a 2D bounding box.
- **Lua-based Logic**: All logic runs server-side within Redis for performance.
- **Simple Architecture**: Uses standard Redis data structures (Hashes, Sorted Sets).

## Limitations

- **Coordinate Range**: Due to signed 32-bit integer limitations in the Lua `bit` library and Redis ZSET sorting, coordinates (x, y) should be within the range [0, 32767] (15-bit). Values larger than this may generate negative Morton codes (due to the 31st bit being set), causing incorrect sorting order in the index.
- **Performance**: The current `zorro_query_range` function scans the entire Z-range between the minimum and maximum Z-values of the bounding box. For large datasets or sparse queries, this might fetch more candidates than necessary before filtering.

## Structure

- `src/`: Contains the Lua source code.
    - `zorrodb.lua`: The main library file containing Morton code logic, storage, and query functions.
- `tests/`: Python integration tests.
- `scripts/`: Helper scripts for deployment.

## Installation & Usage

### Prerequisites

- Redis 7.0 or higher (supports `FUNCTION LOAD`).
- Python 3.x (for testing).

### Deployment

To load the Lua functions into your Redis instance:

```bash
./scripts/load_scripts.sh
```

### API

The following Redis functions are available after loading:

#### `FCALL zorro_insert 0 <id> <x> <y> [key val ...]`

Inserts an object with ID `id` at coordinates `(x, y)` with optional additional fields.

#### `FCALL zorro_get 0 <id>`

Retrieves the data for the object with ID `id`.

#### `FCALL zorro_query_range 0 <x_min> <y_min> <x_max> <y_max>`

Returns a list of IDs for objects located within the specified bounding box.

## Development

1. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```
2. Run tests:
   ```bash
   pytest tests/
   ```
