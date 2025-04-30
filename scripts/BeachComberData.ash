import <vprops.ash>;
import <BeachComberJSON.ash>;

// ***************************
//       Configuration       *
// ***************************

// This package tracks all rare and uncommon tiles.
// There are less than 1000 rares and less than 50,000 uncommons.
//
// It can optionally track commons, as well, but since there are about 950,000 of them,
// that will be data bloat for most users. And, since there are ~95 commons per beach,
// detecting whether a common is new will require an efficient data structure.
//
// It can also track already combed tiles - which will be invaluable in tracking down
// previously unknown unommons and rares - but that will depend on tracking commons.
//
// BeachComber will set this configuration parameter to true if you are spading, and will let
// the user specify whether or not to track rough and combed sand if it is not spading.

boolean parse_commons = define_property( "VBC.ParseCommons", "boolean", "false" ).to_boolean();

// ***************************
//          Beaches          *
// ***************************

// Wandering from 1 to 10,000 "minutes" down the beach gives a distinct
// 100 by 100 section. (Considering that there are 60 * 24 = 1440 minutes
// in an Earth day, KoL is playing rather loosely with its nomenclature;
// 10,000 minutes is almost 7 days.)
//
// This means that there are 10,000 * 10 * 10 = 1,000,000 different squares,
// or "tiles", as various Beach Combing scripts, refer to them.
//
// We'll refer to "a section found by wandering NNNN minutes down the beach"
// as simply "a beach". In particular, "beach #NNNN".

typedef int beach;
typedef boolean[beach] beach_set;
typedef beach[int] beach_list;

// If you want to use "contains" with a beach #, the beach_set is your data structure.
// However, a beach_list (essentially, an array) is  the external format.
beach_set to_beach_set( beach_list list )
{
    beach_set result;
    foreach key, b in list {
	result[b] = true;
    }
    return result;
}

// Adds to the end.
void add_beach(beach_list list, beach b)
{
    list[count(list)] = b;
}

void add_beach(beach_set set, beach b)
{
    set[b] = true;
}

void add_beaches(beach_set set, beach_list input)
{
    foreach key, b in input {
	set.add_beach(b);
    }
}

void add_beaches(beach_set set, beach_set input)
{
    foreach b in input {
	set.add_beach(b);
    }
}

void remove_beaches(beach_set set, beach_list input)
{
    foreach key, b in input {
	remove set[b];
    }
}

void remove_beaches(beach_set set, beach_set input)
{
    foreach b in input {
	remove set[b];
    }
}

int first_beach(beach_set beaches)
{
    foreach b in beaches {
	return b;
    }
    return 0;
}

// Put a beach_set into the external format.
beach_list to_beach_list( beach_set set )
{
    beach_list result;
    foreach b in set {
	result[count(result)] = b;
    }
    return result;
}

// Make a copy of a beach_set so you can modify it and leave it untouched.
beach_set to_beach_set( beach_set set )
{
    beach_set result;
    result.add_beaches(set);
    return result;
}

// A beach_list is sortable, since the actual data is in the value.
// If you don't want to munge an existing list, make a copy of it.
beach_list copy( beach_list list )
{
    beach_list result;
    foreach n, b in list {
	result[n] = b;
    }
    return result;
}

// And here are the import/export function for the external format: a
// JSON array.  Since it is just a list of ints, it could be more
// compact, but for human readability, we'll put 1 beach per line.

buffer beach_list_to_json( beach_list list )
{
    buffer buf = "[";
    foreach key, b in list {
	if (key > 0) {
	    buf.append(",");
	}
	buf.append("\n  ");
	buf.append(b.to_string());
    }
    buf.append("\n]\n");
    return buf;
}

beach_list json_to_beach_list( buffer json )
{
    beach_list result;
    int_array array = parse_json_int_array(json);
    foreach n, value in array {
	result[count(result)] = value;
    }
    return result;
}

// ***************************
//        Coordinates        *
// ***************************

// Beach Layout:
//
//     (XXXX minutes down the beach)
//              column
//     0  1  2  3  4  5  6  7  8  9
// 10  x  x  x  x  x  x  x  x  x  x
//  9  x  x  x  x  x  x  x  x  x  x
//  8  x  x  x  x  x  x  x  x  x  x
//  7  x  x  x  x  x  x  x  x  x  x
//  6  x  x  x  x  x  x  x  x  x  x
//  5  x  x  x  x  x  x  x  x  x  x
//  4  x  x  x  x  x  x  x  x  x  x
//  3  x  x  x  x  x  x  x  x  x  x
//  2  x  x  x  x  x  x  x  x  x  x
// (1) wave washed squares
//
// Tides are cyclical and have an 8-day cycle:
// 0, 1, 2, 3, 4, 3, 2, 1, ...
//
// Coordinates: <row>,(<minute>*10-<column>)
//
// That "coordinates" string appears in the choice command you submit to
// KoL to comb a specific tile on the beach as coords=COORDS.

// This data structure uniquely identifies a tile on the beach

record coords
{
    int minute;		// 1-10000
    int row;		// 1-10 (varies with tide )
    int column;		// 0-9
};

string to_string( coords c )
{
    return "(" + c.minute + "," + c.row + "," + ( c.column + 1 ) + ")";
}

// ***************************
//         URL format        *
// ***************************

// Coordinates: <row>,(<minute>*10-<column>)
//
// Minute: 1-10000
// Row: 1-10 (waves at the bottom might make 1 or more rows uncombable)
// Column: 0-9
//
// This is used in choice.php?whichchoice=1388&option=4&coords=COORDS
//
// Unless you are parsing or creating such URLs, you shouldn't need any of this,
// since KoLmafia's "beach" command (and BeachCombRequest) handles it all for you.

// The string representation is the format expected by KoL in the
// "coords" field of the choice adventure that visits a square

string to_url_string( int minute, int row, int column )
{
    return row + "," + ( (minute * 10) - column );
}

string to_url_string( coords c )
{
    return to_url_string( c.minute, c.row, c.column );
}

coords to_coords( int row, int minute_column )
{
    int minute = minute_column / 10;
    int column = 10 - ( minute_column % 10 );
    if ( column == 10 ) {
	column = 0;
    } else {
	minute++;
    }

    return new coords( minute, row, column );
} 

coords to_coords( string url_coords )
{
    matcher m = create_matcher("(\\d+),(\\d+)", url_coords);
    return m.find() ?
	to_coords(m.group(1).to_int(), m.group(2).to_int()) :
	new coords( 0, 0, 0);
}

// ***************************
//          Hash Key         *
// ***************************

// In order to have Sets of tiles, we can't use the Coordinate record as
// a key, since records are mutable and cannot serve as map keys.

// 1-10.000 minute, 1-10 row, 0-9 column = 10,000 * 10 * 10 = 1,000,000 tiles
// We'll number them from 1 - 1,000,000

int to_key( coords coords )
{
    return (coords.minute - 1) * 100 + (coords.row - 1) * 10 + coords.column + 1;
}

coords to_coords( int key )
{
    key -= 1;
    int minute = ( key / 100 ) + 1;
    int row = ( key / 10 ) % 10 + 1;
    int column = ( key % 10 );
    return new coords( minute, row, column );
}

// ***************************
//        Coords List        *
// ***************************

// A map from hash key -> tile.
//
// Essentially, this is a set of tiles; since the coords can be derived
// from the hash key, we don't REALLY need to store the actual tile.

typedef coords[int] coords_list;

coords_list coords_to_coords_list(coords... coords)
{
    coords_list result;
    foreach n, c in coords {
	result[c.to_key()] = c;
    }
    return result;
}

coords_list copy(coords_list list)
{
    coords_list result;
    foreach n, c in list {
	result[n] = c;
    }
    return result;
}

coords_list flatten(coords_list list)
{
    coords_list flat_list;
    foreach key, tile in list {
	flat_list[count(flat_list)] = tile;
    }
    return flat_list;
}

void add_tile(coords_list list, coords tile)
{
    list[tile.to_key()] = tile;
}

void add_tiles(coords_list list, coords_list tiles)
{
    foreach key, tile in tiles {
	list.add_tile(tile);
    }
}

void remove_tile(coords_list list, coords tile)
{
    remove list[tile.to_key()];
}

void remove_tiles(coords_list list, coords_list tiles)
{
    foreach key, tile in tiles {
	list.remove_tile(tile);
    }
}

// ***************************
//         Coords Map        *
// ***************************

// A Map that lets you look up tiles by # of minutes down the beach.

typedef coords_list[beach] coords_map;

boolean contains_tile(coords_map map, int minute, int row, int column )
{
    coords_list tiles = map[minute];
    foreach n, c in tiles {
	if (c.row == row && c.column == column) {
	    return true;
	}
    }
    return false;
}

boolean contains_tile(coords_map map, coords c)
{
    return map.contains_tile(c.minute, c.row, c.column);
}

void add_tile(coords_map map, coords c)
{
    int minutes = c.minute;
    coords_list list = map[minutes];
    list.add_tile(c);
    map[minutes] = list;
}

void add_tiles(coords_map map, coords_list list)
{
    foreach key, tile in list {
	map.add_tile(tile);
    }
}

boolean remove_tile(coords_map map, coords c)
{
    int minute = c.minute;
    coords_list list = map[minute];

    if (list.count() == 0) {
	return false;
    }

    list.remove_tile(c);
    if (list.count() == 0) {
	remove map[minute];
    }
    return true;
}

void remove_tiles(coords_map map, coords_list list)
{
    foreach key, tile in list {
	map.remove_tile(tile);
    }
}

beach_set to_beach_set(coords_map map)
{
    beach_set result;
    foreach minutes, list in map {
	result[minutes] = true;
    }
    return result;
}

coords_list to_coords_list(coords_map map)
{
    coords_list result;
    foreach minutes, list in map {
	foreach key, tile in list {
	    result[key] = tile;
	}
    }
    return result;
}

coords_list flatten(coords_map map)
{
    coords_list flat_list;
    foreach minutes, list in map {
	foreach key, tile in list {
	    flat_list[count(flat_list)] = tile;
	}
    }
    return flat_list;
}

// ***************************
//     Compact Coords Map    *
// ***************************

// A compact Map that lets you look up tiles by # of minutes down the beach.
// index by [beach, row, column]

typedef boolean [beach, int, int] compact_coords_map;

boolean contains_tile(compact_coords_map map, int minute, int row, int column )
{
    return (map contains minute &&
	    map[minute] contains row &&
	    map[minute][row] contains column);
}

boolean contains_tile(compact_coords_map map, coords c)
{
    return map.contains_tile(c.minute, c.row, c.column);
}

void add_tile(compact_coords_map map, int minute, int row, int column )
{
    if (!map.contains_tile(minute, row, column)) {
	map[minute, row, column] = true;
    }
}

void add_tile(compact_coords_map map, coords c)
{
    map.add_tile(c.minute, c.row, c.column);
}

void add_tiles(compact_coords_map map, coords_list list)
{
    foreach key, tile in list {
	map.add_tile(tile);
    }
}

void add_tiles(compact_coords_map map, compact_coords_map input)
{
    foreach min, row, col in input {
	map.add_tile(min, row, col);
    }
}

boolean remove_tile(compact_coords_map map, int minute, int row, int column)
{
    if (!map.contains_tile(minute, row, column)) {
	return false;
    }

    remove map[minute, row, column];
    if (count(map[minute, row]) == 0) {
	remove map[minute, row];
    }

    if (count(map[minute]) == 0) {
	remove map[minute];
    }
    
    return true;
}

boolean remove_tile(compact_coords_map map, coords c)
{
    return map.remove_tile(c.minute, c.row, c.column);
}

void remove_tiles(compact_coords_map map, coords_list list)
{
    foreach key, tile in list {
	map.remove_tile(tile);
    }
}

void remove_tiles(compact_coords_map map, compact_coords_map input)
{
    foreach minute, row, column in input {
	map.remove_tile(minute, row, column);
    }
}

int count_beaches(compact_coords_map map) {
    return count(map);
}

void keep_tiles(coords_list list, compact_coords_map map)
{
    foreach key, tile in list {
	if (!map.contains_tile(tile)) {
	    list.remove_tile(tile);
	}
    }
}

int count_tiles(compact_coords_map map) {
    int count = 0;
    foreach min, row in map {
	count += count( map[min, row] );
    }
    return count;
}

beach_set to_beach_set(compact_coords_map map)
{
    beach_set result;
    foreach minutes in map {
	result[minutes] = true;
    }
    return result;
}

// ***************************
//      Global Variables     *
// ***************************

// (published) The set of rare tiles imported from combo and discovered by community spading
static coords_list rare_tiles;			// tiles.rare.json

// (published) Uncommon tiles discovered by community spading
static coords_list uncommon_tiles;		// tiles.uncommon.json

// (published) Sand castle tiles (and beaches) discovered by community spading
static coords_list castle_tiles;		// tiles.castle.json

// (published) Sand castle beaches decoded using Wiki's algorithm.
// The starting (highest) beach is #9375
static beach_list castle_beaches_wiki;		// beaches.castle.wiki.json

// (published) Beach Heads
static coords_list beach_heads;			// tiles.beach_heads.json

// (published) Common tiles discovered by community spading
static compact_coords_map common_tiles_map;	// tiles.common.json
 
// (local) Combed tiles discovered by spading
static coords_list combed_tiles;		// tiles.combed.json

coords_map rare_tiles_map;
coords_map verified_tiles_map;
coords_map uncommon_tiles_map;
coords_map castle_tiles_map;
coords_map beach_head_map;
compact_coords_map combed_tiles_map;
compact_coords_map all_common_tiles_map;

beach_set castle_beach_set;

// ***************************
//         Rare Types        *
// ***************************

// If only ASH had enums...

// Cannot be "item", since "pirate" is any of 3 items, "whale" is Meat,
// and "message" is neither.
typedef string rare_type;

static rare_type NOT_RARE = "not rare";
static rare_type RARE_DRIFTWOOD = "piece of driftwood";
static rare_type RARE_PIRATE = "cursed pirate hoard";
static rare_type RARE_MESSAGE = "message in a bottle";
static rare_type RARE_WHALE = "beached whale";
static rare_type RARE_METEORITE = "meteorite fragment";
static rare_type RARE_PEARL = "rainbow pearl";

// A map from index -> tile.
//
// Unlike a coords_list, which indexes from hash key to tile, this allows duplicates

typedef coords[int] tile_list;

tile_list driftwood_tiles;	// tiles.rare.driftwood.json
tile_list pirate_tiles;		// tiles.rare.pirate.json
tile_list message_tiles;	// tiles.rare.message.json
tile_list whale_tiles;		// tiles.rare.whale.json
tile_list meteorite_tiles;	// tiles.rare.meteorite.json
tile_list pearl_tiles;		// tiles.rare.pearl.json

void add_tile(tile_list list, coords tile)
{
    list[count(list)] = tile;
}

typedef int[int] tile_count_map;

tile_count_map to_tile_count_map(tile_list list)
{
    tile_count_map result;
    foreach n, tile in list {
	result[tile.to_key()]++;
    }
    return result;
}

int tile_count(tile_count_map map)
{
    int total = 0;
    foreach key, count in map {
	total += count;
    }
    return total;
}

typedef int[int] beach_count_map;

beach_count_map to_beach_count_map(tile_list list)
{
    beach_count_map result;
    foreach n, tile in list {
	result[tile.minute]++;
    }
    return result;
}

int beach_count(beach_count_map map)
{
    int total = 0;
    foreach key, count in map {
	total += count;
    }
    return total;
}

// ***************************
//         Rarity Map        *
// ***************************

// A map from (int) key -> (string) rarity

// If only ASH had enums...
typedef string rarity;

static rarity TILE_COMMON = "common";
static rarity TILE_UNCOMMON = "uncommon";
static rarity TILE_RARE = "rare";
static rarity TILE_HEAD = "head";
static rarity TILE_CASTLE = "castle";

// A tile's "key" goes from 1-1000000.
// More efficient to use an array with indices 0-999999
typedef rarity[1000000] rarity_map;

rarity_map populate_rarity_map()
{
    rarity categorize(coords tile)
    {
	if (beach_head_map.contains_tile(tile)) {
	    return TILE_HEAD;
	}
	if (castle_tiles_map.contains_tile(tile)) {
	    return TILE_CASTLE;
	}
	if (rare_tiles_map.contains_tile(tile)) {
	    return TILE_RARE;
	}
	if (uncommon_tiles_map.contains_tile(tile)) {
	    return TILE_UNCOMMON;
	}
	// Anything else is a "common" tile.
	return TILE_COMMON;
    }

    rarity_map result;

    for (int key = 1; key <= 1000000; ++key) {
	coords tile = to_coords(key);
	result[key - 1] = tile.categorize();
    }

    return result;
}

void populate_from_rarity_map(rarity_map tiles)
{
    for (int key = 1; key <= 1000000; ++key) {
	coords tile = to_coords(key);
	rarity type = tiles[key - 1];
	switch (type) {
	case TILE_HEAD:
	    beach_head_map.add_tile(tile);
	    break;
	case TILE_CASTLE:
	    castle_tiles_map.add_tile(tile);
	    break;
	case TILE_COMMON:
	    all_common_tiles_map.add_tile(tile);
	    break;
	case TILE_UNCOMMON:
	    uncommon_tiles_map.add_tile(tile);
	    break;
	case TILE_RARE:
	    rare_tiles_map.add_tile(tile);
	    break;
	}
    }
}

buffer rarity_map_to_json(rarity_map tiles)
{
    buffer result;
    result.append("[");
    string comma = "";
    for (int key = 0; key < 1000000; ++key) {
	result.append(comma);
	comma = ",";
	result.append("\n  ");
	result.append(to_json(tiles[key]));
    }
    result.append("\n]");
    return result;
}

string rarity_map_to_ash_map(rarity_map tiles)
{
    buffer result;
    for (int key = 0; key < 1000000; ++key) {
	result.append(to_string(key + 1));
	result.append("\t");
	result.append(tiles[key]);
	result.append("\n");
    }
    return result.to_string();
}

rarity_map to_rarity_map(string[int] map)
{
    rarity make_rarity(string value)
    {
	// Reduce memory usage by using constants.
	// If only ASH had enums...
	switch (value) {
	case TILE_COMMON: return TILE_COMMON;
	case TILE_UNCOMMON: return TILE_UNCOMMON;
	case TILE_RARE: return TILE_RARE;
	case TILE_HEAD: return TILE_HEAD;
	case TILE_CASTLE: return TILE_CASTLE;
	}
	return "";
    }

    rarity_map result;
    foreach key, value in map {
	// Sanity check
	if (key < 1 || key > 1000000) {
	    continue;
	}
	result[key - 1] = make_rarity(value);
    }
    return result;
}

string[int] to_ash_map(rarity_map rarities)
{
    string[int] result;
    for (int key = 0; key < 1000000; ++key) {
	result[key + 1] = rarities[key];
    }
    return result;
}

// ***************************
//         JSON format       *
// ***************************

//  { "minute": 34, "row": 8, "column": 9 }

string coords_to_json( int minute, int row, int column )
{
    return "{ \"minute\": " + minute + ", \"row\": " + row + ", \"column\": " + column + " }";
}

string coords_to_json( coords coords )
{
    return coords_to_json( coords.minute, coords.row, coords.column );
}

coords json_to_coords( string json )
{
    json_object object = parse_json_object(json);
    int minute = object.get_json_int("minute");
    int row = object.get_json_int("row");
    int column = object.get_json_int("column");
    return new coords(minute, row, column);
}

coords_list json_to_coords_list( buffer json )
{
    coords_list result;
    json_array array = parse_json_array(json);
    foreach n, value in array {
	coords coords = json_to_coords(value);
	int key = coords.to_key();
	result[key] = coords;
    }
    return result;
}

tile_list json_to_tile_list( buffer json )
{
    tile_list result;
    json_array array = parse_json_array(json);
    foreach n, value in array {
	coords coords = json_to_coords(value);
	result.add_tile(coords);
    }
    return result;
}

compact_coords_map json_to_compact_coords_map( buffer json )
{
    compact_coords_map result;
    json_array array = parse_json_array(json);
    foreach n, value in array {
	coords coords = json_to_coords(value);
	result.add_tile(coords);
    }
    return result;
}

buffer coords_list_to_json( coords_list list )
{
    buffer buf = "[";
    int count = 0;
    foreach key, c in list {
	if (count++ > 0) {
	    buf.append(",");
	}
	buf.append("\n  ");
	buf.append(coords_to_json(c));
    }
    buf.append("\n]\n");
    return buf;
}

buffer tile_list_to_json( tile_list list )
{
    buffer buf = "[";
    int count = 0;
    foreach key, c in list {
	if (count++ > 0) {
	    buf.append(",");
	}
	buf.append("\n  ");
	buf.append(coords_to_json(c));
    }
    buf.append("\n]\n");
    return buf;
}

buffer compact_coords_map_to_json( compact_coords_map map )
{
    buffer buf = "[";
    int count = 0;
    foreach min, row, col in map {
	if (count++ > 0) {
	    buf.append(",");
	}
	buf.append("\n  ");
	buf.append(coords_to_json(min, row, col));
    }
    buf.append("\n]\n");
    return buf;
}

// ***************************
//         Read/Write        *
// ***************************

// Files manipulated or created by this package are organized in a
// subdirectory of KoLmafia's "data" directory

static string BEACH_DIRECTORY = "beach";
static string PATH_SEPARATOR = "/";

string beach_file(string directory, string filename)
{
    return directory + PATH_SEPARATOR + fileName;
}

string beach_file(string filename)
{
    return beach_file("data", beach_file(BEACH_DIRECTORY, filename));
}

coords_list load_tiles(string filename)
{
    return file_to_buffer(beach_file(filename)).json_to_coords_list();
}

void save_tiles(coords_list data, string filename)
{
    data.coords_list_to_json().buffer_to_file(beach_file(filename));
}

tile_list load_tile_list(string filename)
{
    return file_to_buffer(beach_file(filename)).json_to_tile_list();
}

void save_tile_list(tile_list data, string filename)
{
    data.tile_list_to_json().buffer_to_file(beach_file(filename));
}

compact_coords_map load_tiles_map(string filename)
{
    return file_to_buffer(beach_file(filename)).json_to_compact_coords_map();
}

void save_tiles_map(compact_coords_map data, string filename)
{
    data.compact_coords_map_to_json().buffer_to_file(beach_file(filename));
}

beach_list load_beaches(string filename)
{
    return file_to_buffer(beach_file(filename)).json_to_beach_list();
}

void save_beaches(beach_list data, string filename)
{
    data.beach_list_to_json().buffer_to_file(beach_file(filename));
}

rarity_map load_rarities(string filename)
{
    string[int] tile_map;
    file_to_map(beach_file(filename), tile_map);
    return tile_map.to_rarity_map();
}

void save_rarities(rarity_map rarities, string filename)
{
    string[int] tile_map = rarities.to_ash_map();
    map_to_file(tile_map, beach_file(filename + ".txt"));
    buffer json = rarities.rarity_map_to_json();
    buffer_to_file(json, beach_file(filename + ".json"));
}

// ***************************
//            Files          *
// ***************************

boolean load_tile_data(boolean verbose)
{
    print("Loading rare tile data...");
    rare_tiles = load_tiles("tiles.rare.json");
    rare_tiles_map.clear();
    rare_tiles_map.add_tiles(rare_tiles);

    print("Loading uncommon tile data...");
    uncommon_tiles = load_tiles("tiles.uncommon.json");
    uncommon_tiles_map.clear();
    uncommon_tiles_map.add_tiles(uncommon_tiles);

    // This consumes lots of memory, time, and disk.
    // Load only if spading
    if (parse_commons) {
	print("Loading common tile data...");
	common_tiles_map = load_tiles_map("tiles.common.json");
	all_common_tiles_map.clear();
	all_common_tiles_map.add_tiles(common_tiles_map);
    }

    print("Loading beach head data...");
    beach_heads = load_tiles("tiles.beach_heads.json");
    beach_head_map.clear();
    beach_head_map.add_tiles(beach_heads);

    print("Loading sand castle data...");
    castle_tiles = load_tiles("tiles.castle.json");
    castle_tiles_map.clear();
    castle_tiles_map.add_tiles(castle_tiles);

    print("Loading combed tile data...");
    combed_tiles = load_tiles("tiles.combed.json");
    combed_tiles_map.clear();
    combed_tiles_map.add_tiles(combed_tiles);

    print("Done loading tile data");

    if (verbose) {
	print();
	print("Rare tiles: " + count(rare_tiles));
	print("Uncommon tiles: " + count(uncommon_tiles));
	print("Common tiles: " + common_tiles_map.count_tiles());
	print("Beach Heads: " + count(beach_heads));
	print("Sand Castles: " + count(castle_tiles));
	print("combed tiles: " + count(combed_tiles));

	print();
	print("Beaches with rare tiles: " + count(rare_tiles_map));
	print("Beaches with uncommon tiles: " + count(uncommon_tiles_map));
	print("Beaches with common tiles: " + all_common_tiles_map.count_beaches());
	print("Beaches with beach heads: " + count(beach_head_map));
	print("Beaches with sand castles: " + count(castle_tiles_map));
	print("Beaches with combed tiles: " + count(combed_tiles_map));
	print();
    }

    return true;
}

void save_tile_data()
{
    save_tiles(combed_tiles, "tiles.combed.json");
}

boolean load_rare_type_data(boolean verbose)
{
    driftwood_tiles = load_tile_list("tiles.rare.driftwood.json");
    pirate_tiles = load_tile_list("tiles.rare.pirate.json");
    message_tiles = load_tile_list("tiles.rare.message.json");
    whale_tiles = load_tile_list("tiles.rare.whale.json");
    meteorite_tiles = load_tile_list("tiles.rare.meteorite.json");
    pearl_tiles = load_tile_list("tiles.rare.pearl.json");
    if (verbose) {
	void print_list_counts(string name, tile_list list)
	{
	    int count = count(list);
	    int tcount = count(list.to_tile_count_map());
	    int bcount = count(list.to_beach_count_map());
	    print(name + count + " (" + tcount + " tiles, " + bcount + " beaches)");
	}

	print();
	print_list_counts("Driftwood: ", driftwood_tiles);
	print_list_counts("Pirate hoards: ", pirate_tiles);
	print_list_counts("Message bottles: ", message_tiles);
	print_list_counts("Whales: ", whale_tiles);
	print_list_counts("Meteorite fragments: ", meteorite_tiles);
	print_list_counts("Rainbow pearls: ", pearl_tiles);

    }

    return true;
}

void save_rare_type_data()
{
    save_tile_list(driftwood_tiles, "tiles.rare.driftwood.json");
    save_tile_list(pirate_tiles, "tiles.rare.pirate.json");
    save_tile_list(message_tiles, "tiles.rare.message.json");
    save_tile_list(whale_tiles, "tiles.rare.whale.json");
    save_tile_list(meteorite_tiles, "tiles.rare.meteorite.json");
    save_tile_list(pearl_tiles, "tiles.rare.pearl.json");
}

// ***************************
//          Utilities        *
// ***************************

// For exporting tile data into new compact format

void import_tiles(boolean verbose)
{
}

void export_tiles(boolean verbose)
{
    rarity_map rarities = populate_rarity_map();
    save_rarities(rarities, "tiles.rarities");
}
