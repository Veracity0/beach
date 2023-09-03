import <BeachComberJSON.ash>;

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
// The number of rows on the beach changes from day to day. Tides?
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

typedef coords_list[int] coords_map;

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

coords_list to_coords_list(coords_map map)
{
    coords_list result;
    foreach beach, list in map {
	foreach key, tile in list {
	    result[key] = tile;
	}
    }
    return result;
}

coords_list flatten(coords_map map)
{
    coords_list flat_list;
    foreach beach, list in map {
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

// (published) Sand castles discovered by community spading
static coords_list castle_tiles;	// tiles.castle.json
// (local) Sand castles not in castle_tiles
static coords_list castle_tiles_new;	// tiles.castle.new.json

// All sand castle tiles = castle_tiles + castle_tiles_new

// (local) The last segment of the beach that we have looked at and started combing.
static int spade_last_minutes;		// spade.minutes.txt

coords_map twinkles_map;
coords_map rare_tiles_map;
coords_map verified_tiles_map;
coords_map uncommon_tiles_map;
coords_map castle_tiles_map;

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

// ***************************
//            Files          *
// ***************************

void populate_tile_maps(boolean verbose)
{
    twinkles_map.add_tiles(twinkle_tiles);
    rare_tiles_map.add_tiles(rare_tiles);
    rare_tiles_map.add_tiles(rare_tiles_new);
    rare_tiles_map.remove_tiles(rare_tiles_errors);
    verified_tiles_map.add_tiles(rare_tiles_verified);
    verified_tiles_map.add_tiles(rare_tiles_seen);
    uncommon_tiles_map.add_tiles(uncommon_tiles);
    uncommon_tiles_map.add_tiles(uncommon_tiles_new);
    castle_tiles_map.add_tiles(castle_tiles);
    castle_tiles_map.add_tiles(castle_tiles_new);

    if (verbose) {
	print("Beaches with rare tiles: " + count(rare_tiles_map));
	print("Beaches with uncommon tiles: " + count(uncommon_tiles_map));
	print("Beaches with sand castles: " + count(castle_tiles_map));
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
    castle_tiles = load_tiles("tiles.castle.json");
    castle_tiles_new = load_tiles("tiles.castle.new.json");

    spade_last_minutes = file_to_buffer(beach_file("spade.minutes.txt")).to_string().to_int();

    if (verbose) {
	print("Unvisited twinkle tiles: " + count(twinkle_tiles));
	print("Known rare tiles: " + count(rare_tiles));
	print("Erroneous rare tiles: " + count(rare_tiles_errors));
	print("New rare tiles: " + count(rare_tiles_new));
	print("Verified rare tiles: " + count(rare_tiles_verified));
	print("Not previously verified rare tiles: " + count(rare_tiles_seen));
	print("Known uncommon tiles: " + count(uncommon_tiles));
	print("New uncommon tiles: " + count(uncommon_tiles_new));
	print("Known sand castles: " + count(castle_tiles));
	print("New sand castles: " + count(castle_tiles_new));
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
    save_tiles(castle_tiles_new, "tiles.castle.new.json");

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
	// *** later
	// save_tiles(rare_tiles, "tiles.rare.json");
    }

    void merge_verified_tiles()
    {
	// Verfied tiles
	verified_tiles_map.clear();
	verified_tiles_map.add_tiles(rare_tiles_verified);
	verified_tiles_map.add_tiles(rare_tiles_seen);
	coords_list merged_verified_tiles = to_coords_list(verified_tiles_map);

	int known_verified_count = count(rare_tiles_verified);
	int new_verified_count = count(rare_tiles_seen);
	int merged_verified_count = count(merged_verified_tiles);

	if (verbose) {
	    print("Verified rare tiles: " + known_verified_count);
	    print("Newly seen rare tiles tiles: " + new_verified_count);
	    print("Merged verified tiles: " + merged_verified_count);
	}

	if (known_verified_count < merged_verified_count) {
	    rare_tiles_verified = merged_verified_tiles;
	    rare_tiles_seen.clear();
	    save_tiles(rare_tiles_verified, "tiles.rare.verified.json");
	    save_tiles(rare_tiles_seen, "tiles.rare.seen.json");
	}
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

	if (known_uncommon_count < merged_uncommon_count) {
	    uncommon_tiles = merged_uncommon_tiles;
	    uncommon_tiles_new.clear();
	    save_tiles(uncommon_tiles, "tiles.uncommon.json");
	    save_tiles(uncommon_tiles_new, "tiles.uncommon.new.json");
	}
    }

    void merge_castle_tiles()
    {
	// Sand Castle tiles
	castle_tiles_map.clear();
	castle_tiles_map.add_tiles(castle_tiles);
	castle_tiles_map.add_tiles(castle_tiles_new);
	coords_list merged_castle_tiles = to_coords_list(castle_tiles_map);

	int known_castle_count = count(castle_tiles);
	int new_castle_count = count(castle_tiles_new);
	int merged_castle_count = count(merged_castle_tiles);

	if (verbose) {
	    print("Known sand castle tiles: " + known_castle_count);
	    print("New sand castle tiles: " + new_castle_count);
	    print("Merged sand castle tiles: " + merged_castle_count);
	}

	if (known_castle_count < merged_castle_count) {
	    castle_tiles = merged_castle_tiles;
	    castle_tiles_new.clear();
	    save_tiles(castle_tiles, "tiles.castle.json");
	    save_tiles(castle_tiles_new, "tiles.castle.new.json");
	}
    }

    merge_rare_tiles();
    merge_verified_tiles();
    merge_uncommon_tiles();
    merge_castle_tiles();
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

    void prune_castle_tiles()
    {
	// Sand castle tiles
	int known_castle_count = count(castle_tiles);
	int original_new_count = count(castle_tiles_new);
	castle_tiles_new.remove_tiles(castle_tiles);
	int new_new_count = count(castle_tiles_new);

	if (verbose) {
	    print("Known sand castles: " + known_castle_count);
	    print("Locally discovered sand castles tiles: " + original_new_count);
	    print("Not yet integrated sand castles: " + new_new_count);
	}

	if (save) {
	    save_tiles(castle_tiles_new, "tiles.castle.new.json");
	}
    }

    prune_rare_tiles();
    prune_verified_tiles();
    prune_uncommon_tiles();
    prune_castle_tiles();
}
