import <BeachComberJSON.ash>;

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

// If you want to use "contains" with a beach #, the beach_set is your daa structure.
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
    int row = ( key / 10 ) % 100 + 1;
    int column = ( key % 100 );
    return new coords( minute, row, column );
}

// ***************************
//        Coords List        *
// ***************************

// A map from hash key -> tile.
//
// Essentially, this is a set of tiles; since the coords can be derived
// from the has key, we don't REALLY need to store the actual tile.

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
//      Global Variables     *
// ***************************

// (local) All twinkle tiles we have seen on the beach but have not visited
static coords_list twinkle_tiles;	// tiles.twinkles.json

// (published) The set of rare tiles imported from combo
static coords_list rare_tiles;		// tiles.rare.json
// (local) Rare tiles not in rare_tiles
static coords_list rare_tiles_new;	// tiles.rare.new.json
// (local) Rare tiles from combo that we have visited and were not rare
static coords_list rare_tiles_errors;	// tiles.rare.errors.json

// All rare tiles = rare_tiles + rare_tiles_new - rare_files_errors

// (published) Rare tiles from combo that have been verified
static coords_list rare_tiles_verified;	// tiles.rare.verified.json
// (local) Rare tiles from combo that we have visited and verified
static coords_list rare_tiles_seen;	// tiles.rare.seen.json

// All verified rare tiles = rare_tiles_verified + rare_tiles_seen

// (published) Uncommon tiles discovered by community spading
static coords_list uncommon_tiles;	// tiles.uncommon.json
// (local) Uncommon tiles not in uncommon_tiles
static coords_list uncommon_tiles_new;	// tiles.uncommon.new.json

// All uncommon tiles = uncommon_tiles + uncommon_tiles_new

// (published) Sand castle beaches discovered by community spading
static beach_list castle_beaches;	// beaches.castle.json
// (local) Sand castles not in castle_beaches
static beach_list castle_beaches_seen;	// beaches.castle.seen.json

// All sand castle beaches = castle_beaches + castle_beaches_seen

// (published) Sand castle beaches decoded using Wiki's algorithm.
// The starting (highest) beach is #9375
static beach_list castle_beaches_wiki;	// beaches.castle.wiki.json

// (local) The last segment of the beach that we have looked at and started combing.
static int spade_last_minutes;		// spade.minutes.txt

coords_map twinkles_map;
coords_map rare_tiles_map;
coords_map verified_tiles_map;
coords_map uncommon_tiles_map;
beach_set castle_beach_set;

// ***************************
//         JSON format       *
// ***************************

//  { "minute": 34, "row": 8, "column": 9 }

string coords_to_json( coords coords )
{
    return "{ \"minute\": " + coords.minute + ", \"row\": " + coords.row + ", \"column\": " + coords.column + " }";
}

coords json_to_coords( string json )
{
    json_object object = parse_json_object(json);
    int minute = object.get_json_int("minute");
    int row = object.get_json_int("row");
    int column = object.get_json_int("column");
    return new coords(minute, row, column);
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

beach_list load_beaches(string filename)
{
    return file_to_buffer(beach_file(filename)).json_to_beach_list();
}

void save_beaches(beach_list data, string filename)
{
    data.beach_list_to_json().buffer_to_file(beach_file(filename));
}

// ***************************
//            Files          *
// ***************************

void populate_tile_maps(boolean verbose)
{
    twinkles_map.clear();
    twinkles_map.add_tiles(twinkle_tiles);
    rare_tiles_map.clear();
    rare_tiles_map.add_tiles(rare_tiles);
    rare_tiles_map.add_tiles(rare_tiles_new);
    rare_tiles_map.remove_tiles(rare_tiles_errors);
    verified_tiles_map.clear();
    verified_tiles_map.add_tiles(rare_tiles_verified);
    verified_tiles_map.add_tiles(rare_tiles_seen);
    uncommon_tiles_map.clear();
    uncommon_tiles_map.add_tiles(uncommon_tiles);
    uncommon_tiles_map.add_tiles(uncommon_tiles_new);
    castle_beach_set.clear();
    castle_beach_set.add_beaches(castle_beaches);
    castle_beach_set.add_beaches(castle_beaches_seen);

    if (verbose) {
	print("Beaches with rare tiles: " + count(rare_tiles_map));
	print("Beaches with verified rare tiles: " + count(verified_tiles_map));
	print("Beaches with uncommon tiles: " + count(uncommon_tiles_map));
	print("Beaches with sand castles: " + count(castle_beach_set));
	print("Beaches with unvisited twinkles: " + count(twinkles_map));
	print();
    }
}

boolean load_tile_data(boolean verbose)
{
    twinkle_tiles = load_tiles("tiles.twinkle.json");
    rare_tiles = load_tiles("tiles.rare.json");
    rare_tiles_new = load_tiles("tiles.rare.new.json");
    rare_tiles_errors = load_tiles("tiles.rare.errors.json");
    rare_tiles_verified = load_tiles("tiles.rare.verified.json");
    rare_tiles_seen = load_tiles("tiles.rare.seen.json");
    uncommon_tiles = load_tiles("tiles.uncommon.json");
    uncommon_tiles_new = load_tiles("tiles.uncommon.new.json");
    castle_beaches = load_beaches("beaches.castle.json");
    castle_beaches_seen = load_beaches("beaches.castle.seen.json");
    castle_beaches_wiki = load_beaches("beaches.castle.wiki.json");

    spade_last_minutes = file_to_buffer(beach_file("spade.minutes.txt")).to_string().to_int();

    if (verbose) {
	print("Known rare tiles: " + count(rare_tiles));
	// The following may have already been merged
	print("Locally discvered rare tiles: " + count(rare_tiles_new));
	print("Erroneous rare tiles: " + count(rare_tiles_errors));
	// Therefore, do not tally them.
	// int total_rare = count(rare_tiles) + count(rare_tiles_new) - count(rare_tiles_errors);
	// print("Total: " + total_rare);
	print();
	print("Verified rare tiles: " + count(rare_tiles_verified));
	print("Newly verified rare tiles: " + count(rare_tiles_seen));
	int total_verified = count(rare_tiles_verified) + count(rare_tiles_seen);
	print("Total: " + total_verified);
	print();
	print("Known uncommon tiles: " + count(uncommon_tiles));
	print("New uncommon tiles: " + count(uncommon_tiles_new));
	int total_uncommon = count(uncommon_tiles) + count(uncommon_tiles_new);
	print("Total: " + total_uncommon);
	print();
	print("Known sand castle beaches: " + count(castle_beaches));
	print("New sand castle beaches: " + count(castle_beaches_seen));
	print();
	print("Unvisited twinkle tiles: " + count(twinkle_tiles));
	print("Last minutes down the beach spaded: " + spade_last_minutes);
	print();
    }

    populate_tile_maps(verbose);

    return true;
}

void save_tile_data()
{
    save_tiles(twinkle_tiles, "tiles.twinkle.json");
    save_tiles(rare_tiles_new, "tiles.rare.new.json");
    save_tiles(rare_tiles_errors, "tiles.rare.errors.json");
    save_tiles(rare_tiles_seen, "tiles.rare.seen.json");
    save_tiles(uncommon_tiles_new, "tiles.uncommon.new.json");
    sort castle_beaches_seen by value;
    save_beaches(castle_beaches_seen, "beaches.castle.seen.json");

    buffer spade_minutes = to_string(spade_last_minutes);
    buffer_to_file(spade_minutes, beach_file("spade.minutes.txt"));
}

// For merging newly discovered tiles into known tile lists.
// This is for publishing updated data files

void merge_tile_data(boolean verbose)
{
    void merge_rare_tiles()
    {
	// Rare tiles
	rare_tiles_map.clear();
	rare_tiles_map.add_tiles(rare_tiles);
	rare_tiles_map.add_tiles(rare_tiles_new);
	rare_tiles_map.remove_tiles(rare_tiles_errors);
	coords_list merged_rare_tiles = to_coords_list(rare_tiles_map);

	int known_rare_count = count(rare_tiles);
	int new_rare_count = count(rare_tiles_new);
	int errors_rare_count = count(rare_tiles_errors);
	int merged_rare_count = count(merged_rare_tiles);

	if (verbose) {
	    print("Known rare tiles: " + known_rare_count);
	    print("Discovered rare tiles: " + new_rare_count);
	    print("Erroneous rare tiles: " + errors_rare_count);
	    print("Merged rare tiles: " + merged_rare_count);
	}

	rare_tiles = merged_rare_tiles;
	save_tiles(rare_tiles, "tiles.rare.json");

	// Preserve new rare and erroneous rare counts.
	// They are the "important" spading results.
	//
	// rare_tiles_new.clear();
	// save_tiles(rare_tiles_new, "tiles.rare.new.json");
	// rare_tiles_errors.clear();
	// save_tiles(rare_tiles_errors, "tiles.rare.errors.json");
    }

    void merge_verified_tiles()
    {
	// Verified rare tiles
	verified_tiles_map.clear();
	verified_tiles_map.add_tiles(rare_tiles_verified);
	verified_tiles_map.add_tiles(rare_tiles_seen);
	coords_list merged_verified_tiles = to_coords_list(verified_tiles_map);

	int known_verified_count = count(rare_tiles_verified);
	int new_verified_count = count(rare_tiles_seen);
	int merged_verified_count = count(merged_verified_tiles);

	if (verbose) {
	    print("Verified rare tiles: " + known_verified_count);
	    print("Newly seen rare tiles: " + new_verified_count);
	    print("Merged verified tiles: " + merged_verified_count);
	}

	rare_tiles_verified = merged_verified_tiles;
	rare_tiles_seen.clear();
	save_tiles(rare_tiles_verified, "tiles.rare.verified.json");
	save_tiles(rare_tiles_seen, "tiles.rare.seen.json");
    }

    void merge_uncommon_tiles()
    {
	// Uncommon tiles
	uncommon_tiles_map.clear();
	uncommon_tiles_map.add_tiles(uncommon_tiles);
	uncommon_tiles_map.add_tiles(uncommon_tiles_new);
	coords_list merged_uncommon_tiles = to_coords_list(uncommon_tiles_map);

	int known_uncommon_count = count(uncommon_tiles);
	int new_uncommon_count = count(uncommon_tiles_new);
	int merged_uncommon_count = count(merged_uncommon_tiles);

	if (verbose) {
	    print("Known uncommon tiles: " + known_uncommon_count);
	    print("New uncommon tiles: " + new_uncommon_count);
	    print("Merged uncommon tiles: " + merged_uncommon_count);
	}

	uncommon_tiles = merged_uncommon_tiles;
	uncommon_tiles_new.clear();
	save_tiles(uncommon_tiles, "tiles.uncommon.json");
	save_tiles(uncommon_tiles_new, "tiles.uncommon.new.json");
    }

    void merge_castle_beaches()
    {
	// Sand Castle beaches
	castle_beach_set.clear();
	castle_beach_set.add_beaches(castle_beaches);
	castle_beach_set.add_beaches(castle_beaches_seen);
	beach_list merged_castle_beaches = castle_beach_set;

	int known_castle_beach_count = count(castle_beaches);
	int new_castle_beach_count = count(castle_beaches_seen);
	int merged_castle_beach_count = count(merged_castle_beaches);

	if (verbose) {
	    print("Known sand castle beaches: " + known_castle_beach_count);
	    print("New sand castle beaches: " + new_castle_beach_count);
	    print("Merged sand castle beaches: " + merged_castle_beach_count);
	}

	castle_beaches = merged_castle_beaches;
	castle_beaches_seen.clear();
	save_beaches(castle_beaches, "beaches.castle.json");
	save_beaches(castle_beaches_seen, "beaches.castle.seen.json");
    }

    merge_rare_tiles();
    merge_verified_tiles();
    merge_uncommon_tiles();
    merge_castle_beaches();
}

// For pruning published tile data from your locally discovered tile data.
// This is for sharing only new data with the project.

void prune_tile_data(boolean verbose, boolean save)
{
    void prune_rare_tiles()
    {
	// Rare tiles
	int known_rare_count = count(rare_tiles);
	int original_new_count = count(rare_tiles_new);
	rare_tiles_new.remove_tiles(rare_tiles);
	int new_new_count = count(rare_tiles_new);

	if (verbose) {
	    print("Known rare tiles: " + known_rare_count);
	    print("Locally discovered rare tiles: " + original_new_count);
	    print("Not yet integrated rare tiles: " + new_new_count);
	}

	if (save) {
	    save_tiles(rare_tiles_new, "tiles.rare.new.json");
	}
    }

    void prune_verified_tiles()
    {
	// Verified tiles
	int known_verified_count = count(rare_tiles_verified);
	int original_seen_count = count(rare_tiles_seen);
	rare_tiles_seen.remove_tiles(rare_tiles_verified);
	rare_tiles_seen.remove_tiles(rare_tiles_new);
	int new_seen_count = count(rare_tiles_seen);

	if (verbose) {
	    print("Verified rare tiles: " + known_verified_count);
	    print("Locally seen rare tiles: " + original_seen_count);
	    print("Not yet integrated verified tiles: " + new_seen_count);
	}

	if (save) {
	    save_tiles(rare_tiles_seen, "tiles.rare.seen.json");
	}
    }

    void prune_uncommon_tiles()
    {
	// Uncommon tiles
	int known_uncommon_count = count(uncommon_tiles);
	int original_new_count = count(uncommon_tiles_new);
	uncommon_tiles_new.remove_tiles(uncommon_tiles);
	int new_new_count = count(uncommon_tiles_new);

	if (verbose) {
	    print("Known uncommon tiles: " + known_uncommon_count);
	    print("Locally discovered uncommon tiles: " + original_new_count);
	    print("Not yet integrated uncommon tiles: " + new_new_count);
	}

	if (save) {
	    save_tiles(uncommon_tiles_new, "tiles.uncommon.new.json");
	}
    }

    void prune_castle_beaches()
    {
	// Sand castle tiles
	int known_castle_beach_count = count(castle_beaches);
	// It's a lot easier to remove a beach from a map than a list with an unknown key
	// ASH will auto-coerce between a beach_list and a beach_set
	// (in either direction) using to_beach_set() and to_beach_list()
	beach_set castle_beaches_seen_set = castle_beaches_seen;
	int original_seen_beach_count = count(castle_beaches_seen_set);
	castle_beaches_seen_set.remove_beaches(castle_beaches);
	castle_beaches_seen = castle_beaches_seen_set;
	int new_seen_beach_count = count(castle_beaches_seen);

	if (verbose) {
	    print("Known sand castle beaches: " + known_castle_beach_count);
	    print("Locally seen sand castles beaches: " + original_seen_beach_count);
	    print("Not yet integrated sand castle beaches: " + new_seen_beach_count);
	}

	if (save) {
	    save_beaches(castle_beaches_seen, "beaches.castle.seen.json");
	}
    }

    prune_rare_tiles();
    prune_verified_tiles();
    prune_uncommon_tiles();
    prune_castle_beaches();
}
