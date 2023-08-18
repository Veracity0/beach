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

// A map from hash key -> tile.
//
// Essentially, this is a set of tiles; since the coords can be derived
// from the has key, we don't REALLY need to store the actual tile.

typedef coords[int] coords_list;

void add_tile(coords_list list, coords tile)
{
    list[tile.to_key()] = tile;
}

void add_tiles(coords_list list, coords_list tiles)
{
    foreach key, tile in tiles {
	list[tile.to_key()] = tile;
    }
}

void remove_tile(coords_list list, coords tile)
{
    remove list[tile.to_key()];
}

// ***************************
//         JSON format       *
// ***************************

//  { "minute": 34, "row": 8, "column": 9 }

string coords_to_json( coords coords )
{
    return "{ \"minute\": " + coords.minute + ", \"row\": " + coords.row + " , \"column\": " + coords.column + " }";
}

coords json_to_coords( string json )
{
    json_object object = parse_json_object(json);
    int minute = object.get_json_int("minute");
    int row = object.get_json_int("row");
    int column = object.get_json_int("column");
    return new coords(minute, row, column);
}

coords_list coords_to_coords_list(coords... coords)
{
    coords_list result;
    foreach n, c in coords {
	result[c.to_key()] = c;
    }
    return result;
}

buffer coords_list_to_json( coords_list list )
{
    string nl = "\n";
    buffer buf;
    buf.append("[");
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

string beach_file(string filename)
{
    return BEACH_DIRECTORY + PATH_SEPARATOR + filename;
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

// All twinkle tiles we have seen on the beach but have not visited
static coords_list twinkle_tiles;

// The set of rare tiles imported from combo
static coords_list rare_tiles;
// Rare tiles from combo that we have visited and verified
static coords_list rare_tiles_seen;
// Rare tiles from combo that we have visited and were not rare
static coords_list rare_tiles_errors;
// Rare tiles not in rare_tiles
static coords_list rare_tiles_new;

// Uncommon tiles discovered by Veracity's spading
static coords_list uncommon_tiles;
// Uncommon tiles not in uncommon_tiles
static coords_list uncommon_tiles_new;

// The last segment of the beach that we have looked at and started combing.
static int spade_last_minutes;

boolean load_tile_data(boolean verbose)
{
    twinkle_tiles = load_tiles("tiles.twinkle.json");
    rare_tiles = load_tiles("tiles.rare.json");
    rare_tiles_seen = load_tiles("tiles.rare.seen.json");
    rare_tiles_errors = load_tiles("tiles.rare.errors.json");
    rare_tiles_new = load_tiles("tiles.rare.new.json");
    uncommon_tiles = load_tiles("tiles.uncommon.json");
    uncommon_tiles_new = load_tiles("tiles.uncommon.new.json");

    spade_last_minutes = file_to_buffer(beach_file("spade.minutes.txt")).to_string().to_int();

    if (verbose) {
	print("Unvisited twinkle tiles: " + count(twinkle_tiles));
	print("Known rare tiles: " + count(rare_tiles));
	print("Verified rare tiles: " + count(rare_tiles_seen));
	print("Erroneous rare tiles: " + count(rare_tiles_errors));
	print("New rare tiles: " + count(rare_tiles_new));
	print("Known uncommon tiles: " + count(uncommon_tiles));
	print("New uncommon tiles: " + count(uncommon_tiles_new));
	print("Last minutes down the beach spaded: " + spade_last_minutes);
    }

    return true;
}

void save_tile_data()
{
    save_tiles(twinkle_tiles, "tiles.twinkle.json");
    save_tiles(rare_tiles_seen, "tiles.rare.seen.json");
    save_tiles(rare_tiles_errors, "tiles.rare.errors.json");
    save_tiles(rare_tiles_new, "tiles.rare.new.json");
    save_tiles(uncommon_tiles_new, "tiles.uncommon.new.json");

    buffer spade_minutes;
    spade_minutes.append(spade_last_minutes);
    buffer_to_file(spade_minutes, beach_file("spade.minutes.txt"));
}
