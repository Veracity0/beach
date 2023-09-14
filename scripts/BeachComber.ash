since r27551;

import <vprops.ash>;
import <BeachComberData.ash>

// ***************************
//          To Do            *
// ***************************

// Support creating a driftwood beach comb from a piece of driftwood?

// ***************************
//        Requirements       *
// ***************************

// A Beach Comb or a driftwood beach comb
// You can have it equipped.
// Otherwise it must be in a place that "retrieve_item" can find it.

item beach_comb = $item[ Beach Comb ];
item driftwood_beach_comb = $item[ driftwood beach comb ];
item piece_of_driftwood = $item[ piece of driftwood ];

// ***************************
//       Configuration       *
// ***************************

typedef string [int] string_list;
typedef boolean [string] string_set;

//-------------------------------------------------------------------------
// All of the configuration variables have default values, which apply
// to any character who does not override the variable using the
// appropriate property.
//
// You can edit the default here in the script and it will apply to all
// characters which do not override it.
//
// define_property( PROPERTY, TYPE, DEFAULT )
// define_property( PROPERTY, TYPE, DEFAULT, COLLECTION )
// define_property( PROPERTY, TYPE, DEFAULT, COLLECTION, DELIMITER )
//
// Otherwise, you can change the value for specific characters in the gCLI:
//
//     set PROPERTY=VALUE
//
// Both DEFAULT and a property VALUE will be normalized
//
// All properties used directly by this script start with "VBC."
//-------------------------------------------------------------------------

// Square picking strategy:
//
// first	pick only the single best patch to comb on a beach.
// twinkle	comb all twinkles on a beach before moving on.

string pick_strategy = define_property( "VBC.PickStrategy", "string", "first" );

// ***************************
//        Validatation       *
// ***************************

static string_set priority_options = $strings[
    ?,
    C,
    H,
    W,
    c,
    r,
    t,
];

static string_set strategy_options = $strings[
    first,
    twinkle
];

void validate_configuration()
{
    boolean valid = true;

    print( "Validating configuration." );

    // Migrate settings.
    if (pick_strategy == "random") {
	set_property("VBC.PickStrategy", "first");
    }

    if ( !( strategy_options contains pick_strategy ) ) {
	print( "VBC.PickStrategy: '" + pick_strategy + "' is invalid.", "red" );
	valid = false;
    }

    if ( !valid ) {
	abort( "Correct those errors and try again." );
    }

    print( "All is well!" );
}

void print_help()
{
    string spaces = "&nbsp;&nbsp;&nbsp;&nbsp;";
    print("BeachComber PARAM...");
    print_html(spaces + "<b>free</b>: comb beach using only free wanders" );
    print_html(spaces + "<b>all</b>: comb beach using free wanders and all remaining turns" );
    print_html(spaces + "<b>NUMBER</b>: comb beach using free wanders and specified number of turns" );
    print_html("");
    print_html(spaces + "<b>random</b>: visit random sections of the beach" );
    print_html(spaces + "<b>rare</b>: visit only sections of the beach with known rare tiles" );
    print_html(spaces + "<b>spade</b>: methodically visit successive sections of the beach" );
    print_html(spaces + "<b>minutes=NUMBER</b>: visit specific section of the beach" );
    print_html("");
    print_html(spaces + "<b>twinkle</b>: comb rare and unknown twinkly tiles" );
    print_html(spaces + "<b>first</b>: comb only the best tile" );
    print_html(spaces + "(the above will comb rough sand if there are no better candidates)" );
    print_html("");
    print_html(spaces + "<b>help</b>: print this message" );
    print_html(spaces + "<b>data</b>: load, analyze, and print tile data, and then exit" );
    print_html(spaces + "<b>prune</b>: prune locally discovered tile data after updating, and then exit" );
}

// Mode for selecting sections of the beach to visit
// 
// random       Walk randomly down the beach and comb tiles
// rare         Walk to beach sections that are known to have rare tiles.
// spade        Walk to next unspaded section of the beach
// minutes=N    Walk N minutes down the beach and comb only that square.
//
// Strategy for picking tiles to comb in a beach section before wandering somewhere else
//
// twinkle      Comb all tiles with a twinkle in a beach section
// known        Comb all uncombed rare tiles (or the first tile with a twinkle)
//
// Specification of how many turns to spend combing tiles
//
// free         Only the (up to) 11 available daily free visits
// all          All available turns
// NNN          free turns (if any) + NNN non-free turns
//
// Special strategies:
//
// We will always skip known rare tiles that are covered by the tides.
//
// If "tidal", we will first consider rare tiles that are the closest to the water,
// since if the tides are receding, that row was just uncovered today.
//
// If "unpublished", we will then look for rare tiles which we have not yet published
//
// If "unverified", we will then look for rare tiles which have not yet been verified.
//
// Interactions:
//
// If "spade", strategy will be "twinkle": comb all twinkles before
// moving to the (numerically) next section of the beach.
//
// If minutes=N, only the specified section of the beach will be visited.
// As many turns as necessary will be used to comb all the "twinkle" tiles.
// After that is completed, execution ends; we will not visit another section.

string mode = "rare";
string strategy = "known";
int turns = 0;
beach minutes = 0;
boolean tidal = false;
boolean unpublished = false;
boolean unverified = false;
boolean completed = false;

void parse_parameters(string... parameters)
{
    boolean bogus = false;
    foreach n, param in parameters {
	if (param == "help") {
	    print_help();
	    exit;
	}
	switch (param) {
	case "":
	    continue;

	// Commands to print or manipulate tile data
	case "data":
	    mode = "data";
	    continue;
	case "prune":
	    mode = "prune";
	    continue;
	case "merge":
	    // Undocumented; for my use only
	    mode = "merge";
	    continue;

	// How many turns to spend combing
	case "free":
	    turns = 0;
	    continue;
	case "all":
	    turns = my_adventures();
	    continue;

	// How to pick which beach to visit
	case "random":
	    // We don't care. Let KoL pick one for us.
	    mode = "random";
	    pick_strategy = "twinkle";
	    continue;
	case "rare":
	    // Go only to beaches where rares have been reported.
	    // Just like everybody else. Let the fastest comber win.
	    // Derby style! Good luck!
	    mode = "rare";
	    pick_strategy = "first";
	    continue;
	case "spade":
	    // We want to methodically visit all the beaches in order to discover
	    // new tile data - potentially including unpublished rares
	    mode = "spade";
	    pick_strategy = "twinkle";
	    continue;

        // Strategies for handling unknown twinkles
	case "first":
	    // Pick only the first.
	    pick_strategy = "first";
	    continue;
	case "twinkle":
	case "twinkles":
	    // Pick all of them. Mini-spading.
	    pick_strategy = "twinkle";
	    continue;

        // Strategies for selecting rare tiles
	case "tidal":
	    // Look first at the row which is next to the water.
	    tidal = true;
	    continue;
	case "unpublished":
	    // Look first for tiles we have discovered but not yet published
	    unpublished = true;
	    continue;
	case "unverified":
	    // Look first for published tiles we have not yet verified
	    unverified = true;
	    continue;
	}

	if (param.is_integer()) {
	    // Use this many (non-free) turns. As opposed to "all".
	    turns = param.to_int();
	    continue;
	}

	if (param.starts_with("minutes=")) {
	    // Investigate a single beach and comb all previously unknown
	    // twinkles, limited by the specified number of turns, if any.
	    int index = param.index_of("=");
	    string value = param.substring(index + 1);
	    minutes = value.is_integer() ? value.to_int() : 0;
	    if (minutes == 0) {
		print("How many minutes?", "red");
		bogus = true;
		continue;
	    }
	    if (minutes < 1 || minutes > 10000) {
		print("You can wander from 1 to 10000 minutes down the beach.", "red");
		bogus = true;
		continue;
	    }
	    mode = "beach";
	    pick_strategy = "twinkle";
	    continue;
	}

	print("I don't understand what '" + param + "' means", "red");
	bogus = true;
	continue;
    }

    if (bogus) {
	print_help();
	exit;
    }
}

// ***************************
//       Data Structures     *
// ***************************

// This script depends on KoLmafia's built-in parsing of the beach when
// you visit it.
//
// _beachMinutes        int
// _beachTides          int
// _beachLayout         ROW:LAYOUT[,...]

int get_minutes()
{
    return get_property( "_beachMinutes" ).to_int();
}

int get_tides()
{
    return get_property( "_beachTides" ).to_int();
}

string get_layout()
{
    return get_property( "_beachLayout" );
}

string set_squares( string squares )
{
    return set_property( "_beachLayout", squares );
}

// These are the codes that KoLmafia returns for various kinds of beach
// squares

static string [string] code_to_type = {
    "t" : "rough sand with a twinkle",
    "r" : "rough sand",
    "c" : "combed sand",
    "C" : "a sand castle",
    "H" : "a beach head",
    "W" : "a beached whale",
    "?" : "unknown",
};

static string [string] type_to_code = {
    "rough sand with a twinkle" : "t",
    "rough sand" : "r",
    "combed sand" : "c",
    "a sand castle" : "C",
    "a beach head" : "H",
    "a beached whale" : "W",
    "unknown" : "?",
};

// This data structure is an easier to use representation of KoLmafia's
// string representation in _beachLayout. It maps row number (an int) to
// 10-character string of squares, coded as above

typedef string [int] beach_layout;

// Function to convert a string compaticle with the _beachLayout
// property to a beach_layout map

beach_layout to_beach_layout( string squares )
{
    beach_layout layout;
    foreach i, row_data in squares.split_string( "," ) {
	int colon = row_data.index_of( ":" );
	if ( colon != -1 ) {
	    int row = row_data.substring( 0, colon ).to_int();
	    string squares = row_data.substring( colon + 1 );
	    layout[ row ] = squares;
	}
    }
    return layout;
}

// Function to convert beach layout map into a string compatible with
// the _beachLaout property

string to_string( beach_layout layout )
{
    buffer value;
    foreach row, squares in layout {
	if ( value.length() > 0 ) {
	    value.append( "," );
	}
	value.append( row );
	value.append( ":" );
	value.append( squares );
    }
    return value.to_string();
}

beach_layout get_beach_layout()
{
    return get_layout().to_beach_layout();
}

void set_beach_layout( beach_layout layout )
{
    set_property( "_beachLayout", layout );
}

string square_at( beach_layout layout, coords c )
{
    return layout[ c.row ].char_at( c.column );
}

beach_layout modify_square( beach_layout layout, coords c, string val )
{
    int row = c.row;
    int column = c.column;

    string squares = layout[ row ];

    buffer modified;
    if ( column > 0 ) {
	modified.append( squares.substring( 0, column ) );
    }
    modified.append( val );
    if ( column < squares.length() - 1 ) {
	modified.append( squares.substring( column + 1, squares.length() ) );
    }

    layout[ row ] = modified;
    return layout;
}

// This data structure contains all of the squares of a beach_layout
// split into sorted lists of coords of a particular coded type, mapping
// from code to list of coords

typedef coords_list [string] sorted_beach_map;

sorted_beach_map sort_beach( int beach, beach_layout layout )
{
    sorted_beach_map map;

    foreach row, squares in layout {
	for ( int col = 0; col < 10; ++col ) {
	    coords c = new coords( beach, row, col );
	    string ch = squares.char_at( col );
	    coords_list clist = map[ ch ];
	    clist.add_tile(c);
	    map[ ch ] = clist;
	}
    }

    foreach ch, clist in map {
	print( count( clist ) + " squares in beach " + beach + " contain " + code_to_type[ ch ] );
    }

    return map;
}

sorted_beach_map sort_beach()
{
    return sort_beach( get_minutes(), get_beach_layout() );
}

void save_visited_tile(coords tile, string tile_type) {
    int key = tile.to_key();
    switch (tile_type) {
    case "rare":
	// If this was a known rare tile, mark it as seen
	if (rare_tiles_verified contains key) {
	    // Previously verified.
	} else if (rare_tiles contains key) {
	    // Not previously verified.
	    rare_tiles_seen.add_tile(tile);
	} else {
	    // Brand new. Score!
	    rare_tiles_new.add_tile(tile);
	}
	return;
    case "uncommon":
	// If we thought this was a rare tile, oops!
	if (rare_tiles contains key) {
	    rare_tiles.remove_tile(tile);
	    rare_tiles_errors.add_tile(tile);
	} else if (uncommon_tiles contains key) {
	    // Been there, done that.
	} else {
	    uncommon_tiles_new.add_tile(tile);
	}
	return;
    default:
	// If we thought this was a rare tile, oops!
	if (rare_tiles contains key) {
	    rare_tiles.remove_tile(tile);
	    rare_tiles_errors.add_tile(tile);
	}
	return;
    }
}

// ***************************
//       Tile Categories     *
// ***************************

// The Wiki uses frequent, infrequent, and scarce.
// I prefer to draw my inspiration from MtG :)

static item_set common_items = $items[ 
    // "Very Commonly"
    driftwood bracelet,
    driftwood pants,
    driftwood hat,
    // "Commonly"
    kelp,
    bunch of sea grapes,
    magenta seashell,
    cyan seashell,
    gray seashell,
    green seashell,
    yellow seashell,
    // "Uncommonly"
    taco shell,
    sea avocado,
    sea carrot,
    sea cucumber,
    // "Rarely"
    beach glass bead,
    coconut shell,
    sea salt crystal,
    sea grease,
    sea jelly,
    sea lace,
    seal tooth,
];

static item_set uncommon_items = $items[ 
    // "Commonly"
    sand dollar,
    dull fish scale,
    // "Uncommonly"
    rough fish scale,
    lucky rabbitfish fin,
    spearfish fishing spear,
    waders,
    // "Rarely"
    pristine fish scale,
    piece of coral,
];

static item_set rare_items = $items[ 
    // "Commonly"
    piece of driftwood,
    // "Rarely"
    cursed pirate cutlass,
    cursed swash buckle,
    cursed tricorn hat,
    // (message in a bottle)
    // "Extremely Rarely"
    meteorite fragment,
    rainbow pearl,
    // (Whale)
];

string categorize_tile(int[item] items)
{
    foreach it in items {
	if (common_items contains it) {
	    return "common";
	}
	if (uncommon_items contains it) {
	    return "uncommon";
	}
	if (rare_items contains it) {
	    return "rare";
	}
    }

    return "unknown";
}

// ***************************
//          Strategies       *
// ***************************

// The last beach we visited.
//
// After combing it, if there are no more twinkles, we'll zero it.
// Therefore, if it is non-zero, it still has twinkles.

int current_beach = 0;

// The tides can cover from 0-4 rows of tiles.
// The Wiki says there is an eight-day cycle:
// 0, 1, 2, 3, 4, 3, 2, 1, 0 ...
//
// row 1: available 1 day out of eight (tides = 0)
// row 2: available 3 days out of eight (tides = 0-1)
// row 3: available 5 days out of eight (tides = 0-2)
// row 4: available 7 days out of eight (tides = 0-3)
// row 5-10: available every day

int current_tides = -1;

// If we are in "rare" mode, we want to look for rares.
// We need more data structures to enable that.

// The list of known uncombed rare tiles.
coords_list available_rare_tiles;

// The list of known rare tiles we have combed
coords_list rare_tiles_combed;

// This list is flattened so we can randomly index into it
coords_list filtered_rare_tiles;

void prepare_rare_tiles(boolean verbose)
{
    // The rare_tiles_map contains tiles from both rare_tiles and
    // rare_tiles_new. Put it into a list so we can filter it.

    available_rare_tiles = rare_tiles_map.to_coords_list();

    // *** It would be nice if we knew  "combed today across all sessions"
    // *** Perhaps have tiles.rare.combed.json and last.combed.date.txt?
    // Remove any we have combed this session.
    available_rare_tiles.remove_tiles(rare_tiles_combed);

    // The tiles are in coordinates order, but are indexed like an
    // array, not by coordinates key. That makes it easy to randomly
    // index into, or sequentially iterate through.

    // combo deterministically (using player id as random seed) shuffles
    // such a list and iterates through it, picking up each day from
    // wherever it left off the previous day.
    //
    // That means that over the course of however many days, you will
    // visit every tile exactly once.
    //
    // I am not convinced that is all that helpful; the tiles do
    // regenerate over time. It's not every rollover, but we don't know
    // how quickly it happens.

    // My initial take is that if we randomly pick a tile from the list -
    // and recreate the list every time we comb one - that will suffice.
}

boolean check_tides(boolean verbose)
{
    // Return true if we filtered out wave-washed tiles
    int tides = get_tides();
    if (tides >= 0 && current_tides != tides) {
	int covered = 0;
	int kept = 0;
	// If tides are from 1-4, all those rows are unavailable.
	int wettest = tides + 1;
	foreach key, coords in available_rare_tiles {
	    if (coords.row < wettest) {
		covered++;
		remove available_rare_tiles[key];
	    } else {
		kept++;
	    }
	}

	if (verbose) {
	    if (covered > 0) {
		print(covered + " rare tiles are washed by the waves");
	    }
	    if (kept > 0) {
		print(kept + " rare tiles are candidates for combing");
	    }
	}

	current_tides = tides;
	return covered > 0;
    }
    return false;
}

boolean filter_rare_tiles(boolean verbose)
{
    // We have three criteria for pruning rare tiles:
    // First visit rare tiles that are next to the water.
    // If none, visit unpublished rare tiles.
    // If none, visit unverified rare tiles.
    // Otherwise, all rare tiles are game.

    coords_list candidates = available_rare_tiles.copy();

    boolean filter_tides()
    {
	// Return true if we filtered out dry tiles

	// If we don't care about the tides, do not filter on them
	if (!tidal) {
	    return false;
	}

	int tides = get_tides();

	// Until we know what the tides are, we cannot filter on them
	if (tides < 0) {
	    return false;
	}

	// If tides are from 1-4, those rows are unavailable.
	int wettest = tides + 1;

	// If the tides are at their highest, we don't care about tides
	// Since nothing new was revealed today.
	if (wettest > 4) {
	    return false;
	}

	int covered = 0;
	int dry = 0;
	int kept = 0;

	foreach key, coords in candidates {
	    // This should be redundant; when we check the tides we already
	    // pruned available_rare_tiles which are covered in water
	    if (coords.row < wettest) {
		covered++;
		remove candidates[key];
	    } else if (coords.row > wettest) {
		dry++;
		remove candidates[key];
	    } else {
		kept++;
	    }
	}

	if (verbose) {
	    if (covered > 0) {
		print(covered + " rare tiles are washed by the waves");
	    }
	    if (dry > 0) {
		print(dry + " rare tiles are too far from the water");
	    }
	    if (kept > 0) {
		print(kept + " rare tiles are candidates for combing");
	    }
	}

	return dry > 0;
    }

    boolean filter_published()
    {
	// Return true if we filtered out published tiles

	// If we don't care about published tides, do not filter on them
	if (!unpublished) {
	    return false;
	}

	// If we don't have any unpublished tiles, do not filter on them
	if (rare_tiles_new.count() == 0) {
	    return false;
	}

	coords_list available_new_tiles;
	int kept = 0;
	foreach key, coords in candidates {
	    if (rare_tiles_new contains coords.to_key()) {
		available_new_tiles.add_tile(coords);
		kept++;
	    }
	}

	// If none of our unpublished tiles is available, do not filter on them.
	if (kept == 0) {
	    return false;
	}

	// If there are some available new tiles, that is the new filtered list
	candidates = available_new_tiles;
	if (verbose) {
	    print(kept + " unpublished tiles are candidates for combing");
	}

	return true;
    }

    boolean filter_unverified()
    {
	// Return true if we filtered out unverified tiles

	// If we don't care about unverified tides, do not filter on them
	if (!unverified) {
	    return false;
	}

	int verified = 0;
	int kept = 0;
	foreach key, coords in candidates {
	    if (rare_tiles_verified contains coords.to_key() ||
		rare_tiles_seen contains coords.to_key()) {
		verified++;
		remove candidates[key];
	    } else {
		kept++;
	    }
	}

	if (verbose) {
	    if (verified > 0) {
		print(verified + " rare tiles have already been verified");
	    }
	    if (kept > 0) {
		print(kept + " unverified rare tiles are candidates for combing");
	    }
	}
	return verified > 0;
    }

    // Return true if any filter removed tiles.
    boolean filtered =  filter_tides() || filter_published() || filter_unverified();
    filtered_rare_tiles = candidates.flatten();
    return filtered;
}

boolean remove_rare_tile(coords c, boolean rare)
{
    if (rare) {
	// It is now combed sand.
	rare_tiles_combed.add_tile(c);
    }
    // If we knew this was rare...
    if (available_rare_tiles contains c.to_key()) {
	// ... don't consider it again this session.
	available_rare_tiles.remove_tile(c);
	// The caller needs to refilter
	return true;
    }

    // Otherwise, this was a new tile, and we don't need to refilter
    return false;
}

int next_rare_beach()
{
    // If we just combed a beach and it still has twinkles,
    // perhaps we want to look at them
    if (current_beach != 0 && pick_strategy == "twinkle") {
	return current_beach;
    }

    int size = filtered_rare_tiles.count();
    if (size > 0) {
	int index = (size == 1) ? 0 : random(size);
	coords tile = filtered_rare_tiles[index];
	print("Looking for rare tile at " + tile);
	return tile.minute;
    }
    // This shouldn't be possible
    return 0;
}

static coords IMPOSSIBLE = new coords(minutes, 10, 0);

coords pick_coords_to_comb( int beach, sorted_beach_map map )
{
    coords pick_index(coords_list clist, int index) {
	if (index < count(clist)) {
	    int i = 0;
	    foreach key, c in clist {
		if (i++ == index) {
		    return c;
		}
	    }
	}
	// This should not be possible
	return IMPOSSIBLE;
    }

    coords pick_random(coords_list clist) {
	int range = count(clist);
	return pick_index(clist, range == 1 ? 0 : random( range ));
    }

    // 1) a whale
    // 2) a known rare tile
    // 3) a hitherto unknown twinkle
    // 4) a known uncommon tile
    // 5) rough sand
    // 6) combed sand

    // 1) If there is a whale, get it.
    coords_list whales = map["W"];
    if (count(whales) > 0) {
	foreach key, c in whales {
	    return c;
	}
    }

    // Get the known twinkles from this beach segment
    coords_list known_rares = rare_tiles_map[beach];
    coords_list known_uncommons = uncommon_tiles_map[beach];

    // Remove already combed rares from consideration
    if (mode == "rare") {
	coords_list combed = map["c"];
	boolean refilter = false;
	foreach key, c in known_rares {
	    if (combed contains key) {
		refilter |= remove_rare_tile(c, true);
	    }
	}
	if (refilter) {
	    filter_rare_tiles(true);
	}
    }

    // Look through currently twinkling tiles
    coords_list twinkles = map["t"];
    if (count(twinkles) > 0) {
	// 2) Look for a rare
	foreach key, c in known_rares {
	    if (twinkles contains key) {
		return c;
	    }
	}
	coords candidate;
	// Remove known uncommons
	foreach key, c in known_uncommons {
	    if (twinkles contains key) {
		candidate = c;
		remove twinkles[key];
	    }
	}
	// 3) If there are remaining twinkles, they are new
	// Return the first one found
	foreach key, c in twinkles {
	    return c;
	}
	// 4) If there is a known uncommon, take it
	if (candidate.minute > 0) {
	    return candidate;
	}
    }

    // There were no twinkles - or the character can't see them.
    // If the latter, we may know of rare and/or uncommon tiles.
    coords_list rough = map["r"];
    if (count(rough) > 0) {
	// 2) Look for a rare
	foreach key, c in known_rares {
	    if (rough contains key) {
		return c;
	    }
	}
	// 4) Look for an uncommon
	foreach key, c in known_uncommons {
	    if (rough contains key) {
		return c;
	    }
	}
	// 5) Comb the first patch of rough sand
	return pick_index(rough, 0);
    }

    // No twinkles or rough sand. Everything is combed?
    // Look at combed sand and take the first we find.
    coords_list combed = map["c"];
    if (count(combed) > 0) {
	// 6) Comb the first patch of combed sand
	return pick_index(combed, 0);
    }

    // Impossible
    return IMPOSSIBLE;
}

// ***************************
//          Utilities        *
// ***************************

buffer use_comb()
{
    // Requires GET
    return visit_url( "main.php?comb=1", false );
}

void put_away_comb()
{
    int choice = last_choice();
    if ( choice == 1388 ) {
	run_choice( 5 );
    }
}

int [string] combed_rarities;
int [string] combed_types;
int combed_meat;
int [item] combed_items;
string [int] beachcombings;

coords_list unknown_tiles(int beach, coords_list tiles, coords_map map)
{
    coords_list knowns = map[beach];
    coords_list unknowns;
    foreach key, c in tiles {
	if (knowns contains key) {
	    continue;
	}
	unknowns.add_tile(c);
    }
    return unknowns;
}

coords_list unknown_twinkles(int beach, coords_list twinkles)
{
    // Only skip known uncommons; we want to visit known rares.
    return unknown_tiles(beach, twinkles, uncommon_tiles_map);
}

void beach_completed()
{
    // We'll stop exploring any beach if it is out of twinkles
    current_beach = 0;

    // If we are exploring a single square, we're done.
    if (minutes != 0) {
	completed = true;
	return;
    }
    // If we are looking for rares and none are left, we're done
    if (mode == "rare") {
	// If we've run out of rare tiles but were checking only the row
	// next to the water, remove that limitation and recalculate.
	if (filtered_rare_tiles.count() == 0 && tidal) {
	    tidal = false;
	    filter_rare_tiles(true);
	}
	// If we've run out of rare tiles but were checking unpublished
	// rares, remove that limitation and recalculate.
	if (filtered_rare_tiles.count() == 0 && unpublished) {
	    unpublished = false;
	    filter_rare_tiles(true);
	}
	// If we've run out of unverified rare tiles but were
	// preferring those, remove that limitation and recalculate.
	if (filtered_rare_tiles.count() == 0 && unverified) {
	    unverified = false;
	    filter_rare_tiles(true);
	}
	// If we've run out of rare tiles (inconceivable!), we're done
	if (filtered_rare_tiles.count() == 0) {
	    completed = true;
	    return;
	}
    }
    // If we are spading multiple squares, move to next square
    if (mode == "spade") {
	spade_last_minutes = ( spade_last_minutes + 1 ) % 10000;
	return;
    }
}

buffer comb_square( coords c, string type )
{
    string cstring = c.to_url_string();
    print( "Combing the square at coordinates " + c + " which contains " + type );
    buffer page = visit_url( "choice.php?whichchoice=1388&option=4&coords=" + cstring );

    // Having combed this square, mark it in settings as combed.
    // This is now done by KoLmafia.
    // beach_layout layout = get_beach_layout().modify_square( c, "c" );
    // set_beach_layout( layout );

    return page;
}

buffer comb_beach( buffer page )
{
    void save_page_html( coords c, buffer page )
    {
	string filename =
	    my_name() +
	    "_" + (c.minute) +
	    "_" + (c.row) +
	    "_" + (c.column + 1) +
	    "_" + now_to_string( "YYYYMMddHHmmssSSS" ) +
	    ".html";
	print( "Saving page HTML to " + filename, "red" );
	beachcombings[ count( beachcombings ) ] = filename;
	page.buffer_to_file(beach_file(beach_file("html", filename)));
    }

    // We depend on KoLmafia to parse the page into properties
    int minutes = get_minutes();
    beach_layout layout = get_beach_layout();
    sorted_beach_map map = sort_beach( minutes, layout );

    // Now that we have the beach map, see how many rows are covered by waves
    if (mode == "rare" && check_tides(true)) {
	// Now that we know the tides, refilter available rare tiles
	filter_rare_tiles(true);
    }

    // Save previously unseen sand castles
    if (count(map["C"]) > 0 && !(castle_beach_set contains minutes)) {
	// Add to the end of the list of seen beaches with a sand castle
	castle_beaches_seen.add_beach(minutes);
	// Keep list in numerical order
	sort castle_beaches_seen by value;
    }

    // Inspect the layout and find all squares with twinkles.
    // (Or a whale)
    coords_list twinkles;
    twinkles.add_tiles(map["W"]);
    twinkles.add_tiles(map["t"]);

    // Save previously unvisited twinkles
    coords_list unknowns = unknown_twinkles( minutes, twinkles );
    twinkle_tiles.add_tiles(unknowns);

    coords c = pick_coords_to_comb( minutes, map );
    string type = code_to_type[ square_at( layout, c ) ];

    // Check if this was a special square
    boolean special = false;

    string tile_type = "unknown";

    // Look for beached whales
    if ( page.contains_text( "whale.png" ) ) {
	print( "You found a beached whale!", "red" );
	// Worth noting, but we also want to learn the hover text
	special = true;
	tile_type = "rare";
    }

    // Look for unknown square types
    if ( type == "?" ) {
	print( "You found an unknown square type!", "red" );
	// Worth noting, and we want to learn everything
	special = true;
    }

    if ( special ) {
	save_page_html( c, page );
	// For the above, log the page after combing, as well.
	// special = false;
    }

    page = comb_square( c, type );

    // Remove the newly combed tile from previously unknown twinkles
    int key = c.to_key();
    remove twinkle_tiles[key];
    remove unknowns[key];

    // Whether or not we found a rare tile, we may have tried to comb one.
    if (mode == "rare" && remove_rare_tile(c, type == "rare")) {
	filter_rare_tiles(true);
    }

    // We don't intentionally farm more than once in a beach segment
    // with no unknown twinkles.
    if (pick_strategy == "first" || count(unknowns) == 0) {
	beach_completed();
    }

    // Look for rainbow pearls
    if ( page.contains_text( "rainbow pearl" ) ) {
	print( "You found a rainbow pearl!", "red" );
	// Let's see the the result text
	special = true;
	tile_type = "rare";
    }

    // Look for meteorite fragments
    if ( page.contains_text( "meteorite fragment" ) ) {
	print( "You found a meteorite fragment!", "red" );
	// Let's see the the result text
	special = true;
	tile_type = "rare";
    }

    // Look for cursed pirate stuff
    if ( page.contains_text( "cursed pirate cutlass" ) ||
	 page.contains_text( "cursed tricorn hat" ) ||
	 page.contains_text( "cursed swash buckle" ) ) {
	print( "You found a cursed pirate hoard!", "red" );
	// Let's see the the result text
	special = true;
	tile_type = "rare";
    }

    // Look for messages in bottles
    if ( page.contains_text( "like it contains some sort of message" ) ) {
	print( "You found a message in a bottle!", "red" );
	// Let's see the the result text and learn how to parse out the message.
	special = true;
	tile_type = "rare";
    }

    int meat = page.extract_meat();
    int[item] items = page.extract_items();

    if (type != "combed sand" && tile_type == "unknown") {
	// Figure it out from the item drops
	tile_type = categorize_tile(items);
    }

    print( c + " is a" + (tile_type == "uncommon" ? "n" : "") + " '" + tile_type + "' tile.");

    save_visited_tile(c, tile_type);

    // Accumulate findings

    combed_rarities[ tile_type ]++;
    combed_types[ type ]++;
    combed_meat += meat;
    foreach it, count in items {
	combed_items[ it ] += count;
    }

    if ( special ) {
	save_page_html( c, page );
    }

    return page;
}

buffer comb_specific_beach( int minutes )
{
    buffer page = run_choice( 1, "minutes=" + minutes );
    current_beach = get_minutes();
    return comb_beach( page );
}

buffer comb_random_beach()
{
    // Wander to a random spot
    buffer page = run_choice( 2 );
    current_beach = get_minutes();
    return comb_beach( page );
}

buffer comb_next_beach()
{
    // Top level control for picking which beach to comb.
    // The comb has been used and the top-level choice is availabe.
    // We can either go to a RANDOM beach, or we can WANDER for a
    // specific number of minutes.

    // Based on "mode"
    //  "random"	Go to a new beach every time
    //  "rare"		Go to a beach with known rare tiles
    //  "spade"		Go next beach we are spading
    //  "beach"		Go to specified beach we are spading
    //
    // Based on "pick_strategy"
    //  "first"		Visit at most one tile
    //  "twinkle"	Visit all twinkles

    buffer page;
    switch (mode) {
    case "rare":
	page = comb_specific_beach( next_rare_beach() );
	break;
    case "random":
	// We'll go to random beachs, but might visit all twinkles
	if ( pick_strategy == "first" || current_beach == 0 ) {
	    page = comb_random_beach();
	} else {
	    page = comb_specific_beach( current_beach );
	}
	break;
    case "spade":
	if (spade_last_minutes < 0 || spade_last_minutes >= 10000) {
	    spade_last_minutes = 0;
	}
	page = comb_specific_beach( spade_last_minutes + 1 );
	break;
    case "beach":
	page = comb_specific_beach( minutes );
	break;
    }

    return page;
}

int beach_comb_free( buffer page )
{
    int beaches_combed = 0;
    while ( !completed &&
	    ( page.contains_text( "free walks down the beach" ) ||
	      page.contains_text( "1 free walk down the beach" ) ) ) {
	page = comb_next_beach();
	beaches_combed++;
    }
    return beaches_combed;
}

int beach_comb_turns( buffer page, int turns )
{
    int beaches_combed = 0;
    while ( !completed && my_adventures() > 0 && turns-- > 0 ) {
	page = comb_next_beach();
	beaches_combed++;
    }
    return beaches_combed;
}

buffer pnum( buffer b, int n )
{
    buffer pnum_helper( buffer b, int n, int level )
    {
	if ( n >= 10 ) {
	    pnum_helper( b, n / 10, level + 1 );
	}
	b.append( to_string( n % 10 ) );
	if ( level > 0 && level % 3 == 0 ) {
	    b.append( "," );
	}
	return b;
    }

    if ( n < 0 ) {
	b.append( "-" );
	n = -n;
    }
    return pnum_helper( b, n, 0 );
}

string pnum( int n )
{
    buffer b;
    return pnum( b, n ).to_string();
}

// ***************************
//           Results         *
// ***************************

record results
{
    int common;		// Common tile visited
    int uncommon;	// Uncommon tiles visited
    int rare;		// Rare tiles visited
    int meat;		// Meat collected
    int[item] items;	// Items looted
};

results read_results()
{
    string filename = beach_file("results.json");
    buffer buf = file_to_buffer(filename);
    json_object object = parse_json_object(buf);

    results data;
    data.common = object.get_json_int("common");
    data.uncommon = object.get_json_int("uncommon");
    data.rare = object.get_json_int("rare");
    data.meat = object.get_json_int("meat");
    json_object items = object.get_json_object("items");
    foreach field, count in items {
	data.items[field.to_item()] = count.to_int();
    }
    return data;
}

void write_results(results data)
{
    buffer buf = data.to_json();
    string filename = beach_file("results.json");
    buffer_to_file(buf, filename);
}

void tally_loot()
{
    results data = read_results();
    data.common += combed_rarities["common"];
    data.uncommon += combed_rarities["uncommon"];
    data.rare += combed_rarities["rare"];
    data.meat += combed_meat;
    foreach it, n in combed_items {
	data.items[it] += n;
    }
    write_results(data);
}

// ***************************
//       Master Control      *
// ***************************

void beach_comb_free_only()
{
    buffer page = use_comb();
    int beaches_combed = beach_comb_free( page );
    put_away_comb();
    print( "Combed " + beaches_combed + " patches of beach using no turns." );
}

void beach_comb_turns_only( int turns )
{
    buffer page = use_comb();
    int beaches_combed = beach_comb_turns( page, turns );
    put_away_comb();
    print( "Combed " + beaches_combed + " patches of beach using turns." );

    // Save in a daily property
    int combed_previously = get_property( "_VBC.TurnsSpentCombing" ).to_int();
    int combed_today = combed_previously + beaches_combed;
    set_property( "_VBC.TurnsSpentCombing", combed_today );
}

void main(string... parameters )
{
    // Parameters are optional. Depending on how the script is invoked,
    // there may be a single string with space-separated keywords, or
    // multiple strings. Whichever, turn into an array of keywords.
    string[] params = parameters.join_strings(" ").split_string(" ");

    // Parse parameters, if any. Do it before validating the
    // configuration, since parameters can override properties.
    parse_parameters(params);

    // If user only wants to see the data, load the data verbosely
    // (which will print info) and then exit.
    if (mode == "data") {
	load_tile_data(true);
	exit;
    }

    // For pruning locally discovered tile data after updating
    if (mode == "prune") {
	load_tile_data(true);
	prune_tile_data(true, true);
	exit;
    }

    // For merging locally discovered tile data with released data
    // Undocumented; for my use only!
    if (mode == "merge") {
	load_tile_data(true);
	merge_tile_data(true);
	exit;
    }

    if ( available_amount( beach_comb ) == 0 &&
	 available_amount( driftwood_beach_comb ) == 0) {
        abort( "You don't have a Beach Comb or a driftwood beach comb!" );
    }

    // Ensure configuration is sane
    validate_configuration();

    // Ensure the Beach Comb is either equippped or in inventory
    // The Beach Comb is not a quest item, so could be in closet, say.
    if ( available_amount( beach_comb ) > 0 &&
	 equipped_amount( beach_comb ) == 0 ) {
	retrieve_item( 1, beach_comb );
    }

    // driftwood beach comb is a "lasts until rollover" quest item.
    // That means that if you have one, it is either equipped or in inventory.
    // Therefore, do not need to retrieve it.

    print();
    if (!load_tile_data(true)) {
	abort("Unable to load tile data");
    }

    // If the user wants to comb rare tiles, set up helpful data structures
    if (mode == "rare") {
	// Make a list of all currently known rare tiles
	prepare_rare_tiles(true);
	// Remove all which are currently under water
	check_tides(true);
	// Apply filters and create a "filtered" list.
	filter_rare_tiles(true);
    }

    try {
	// Use all free combs
	beach_comb_free_only();

	// Optionally spend adventures for more combing
	if ( turns > 0 ) {
	    beach_comb_turns_only( turns );
	}
    } finally {
	print();
	print("Saving new tile data...");
	save_tile_data();

	print();
	foreach type in $strings[common, uncommon, rare, unknown] {
	    print( "Found " + combed_rarities[type] + " " + type + " tiles." );
	}

	print();
	foreach type, count in combed_types {
	    print( "Combed " + type + " " + count + " times." );
	}

	print();
	if ( combed_meat > 0 ) {
	    print();
	    print( "Meat combed:" + pnum( combed_meat ) );
	}

	print( "Items combed:" );
	foreach it, count in combed_items {
	    print( it + " (" + count + ")" );
	}

	if ( count( beachcombings ) > 0 ) {
	    print();
	    print( "Special beach combings saved:", "red" );
	    foreach n, filename in beachcombings {
		print( filename );
	    }
	}

	tally_loot();
    }
}