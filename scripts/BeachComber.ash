since r19668;

import <vprops.ash>;

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

// How to prioritize beach squares to comb
//
// W	a beached whale
// ?	an unclassifiable square
// C	a sand castle
// r	rough sand
// t	rough sand with a twinkle
// c	combed sand
// H	a beach head
//
// We think there are fixed set of 11 beach heads, and if you want to
// visit, you can do that manually, so they are not prioritized by
// default. If you want a random buff rather than items, add them.
//
// We do not expect any unidentifiable square. If KoLmafia finds a
// square it cannot classify, it will log it in the gCLI and session log
// and return a "?". This script assumes such squares are worth visiting.

string_list priorities = define_property( "VBC.Priorities", "string", "W,?,t,r,c", "list" ).to_string_list( "," );

// Square picking strategy:
//
// first	pick the first square with the highest priority
//		lowest row, leftmost column
// random	pick randomly from all squares containing the highest priority
// twinkle	comb all patches of rough sand with a twinkle within a beach
//		before moving to another section

string pick_strategy = define_property( "VBC.PickStrategy", "string", "random" );

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
    random,
    twinkle
];

void validate_configuration()
{
    boolean valid = true;

    print( "Validating configuration." );

    boolean tseen = false;
    boolean rseen = false;
    boolean cseen = false;

    foreach index, priority in priorities {
	if ( !( priority_options contains priority ) ) {
	    print( "VBC.Priorities: '" + priority + "' is not a valid square type.", "red" );
	    valid = false;
	} else if ( priority == "r" ) {
	    rseen = true;
	} else if ( priority == "c" ) {
	    cseen = true;
	} else if ( priority == "t" ) {
	    tseen = true;
	}
    }

    // Always put 't', 'r' and 'c' at the end if otherwise not specified
    if ( valid ) {
	if ( !tseen ) {
	    print( "VBC.Priorities: adding 't'." );
	    priorities[ count( priorities ) ] = "t";
	}
	if ( !rseen ) {
	    print( "VBC.Priorities: adding 'r'." );
	    priorities[ count( priorities ) ] = "r";
	}
	if ( !cseen ) {
	    print( "VBC.Priorities: adding 'c'." );
	    priorities[ count( priorities ) ] = "c";
	}
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

// ***************************
//       Data Structures     *
// ***************************

// This script depends on KoLmafia's built-in parsing of the beach when
// you visit it.
//
// _beachMinutes	int
// _beachLayout		ROW:LAYOUT[,...]

int get_minutes()
{
    return get_property( "_beachMinutes" ).to_int();
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

// This data structure uniquely identifies a square on the beach

record coords
{
    int beach;		// 1-10000 (minutes)
    int row;		// 2-10 (varies with tide )
    int col;		// 0-9
};

// The string representation is the format expected by KoL in the
// "coords" field of the choice adventure that visits a square

string to_string( int beach, int row, int col )
{
    return row + "," + ( (beach * 10) - col );
}

string to_string( coords c )
{
    return to_string( c.beach, c.row, c.col );
}

coords to_coords( int row, int beach_col )
{
    int beach = beach_col / 10;
    int col = 10 - ( beach_col % 10 );
    if ( col == 10 ) {
	col = 0;
    } else {
	beach++;
    }

    return new coords( beach, row, col );
} 

string square_at( beach_layout layout, coords c )
{
    return layout[ c.row ].char_at( c.col );
}

// This data structure contains all of the squares of a beach_layout
// split into sorted lists of coords of a particular coded type, mapping
// from code to list of coords

typedef coords [int] coords_list;
typedef coords_list [string] sorted_beach_map;

sorted_beach_map sort_beach( int beach, beach_layout layout )
{
    sorted_beach_map map;

    foreach row, squares in layout {
	for ( int col = 0; col < 10; ++col ) {
	    string ch = squares.char_at( col );
	    coords_list clist = map[ ch ];
	    clist[ count( clist ) ] = new coords( beach, row, col );
	    map[ ch ] = clist;
	}
    }

    foreach ch, list in map {
	print( count( list ) + " squares in beach " + beach + " contain " + code_to_type[ ch ] );
    }

    return map;
}

sorted_beach_map sort_beach()
{
    return sort_beach( get_minutes(), get_beach_layout() );
}

// ***************************
//          Strategies       *
// ***************************

// Pick randomly from all squares of the highest priority

coords pick_random_coords_to_comb( int beach, beach_layout layout )
{
    sorted_beach_map map = sort_beach( beach, layout );

    foreach index, choice in priorities {
	if ( map contains choice ) {
	    coords_list clist = map[ choice ];
	    int range = count( clist );
	    return clist[ range == 1 ? 0 : random( range ) ];
	}
    }

    // This should not be possible
    return new coords( 0, 0, 0 );
}

// Pick the first (lowest row, lowest col) square of the highest priority

coords pick_first_coords_to_comb( int beach, beach_layout layout )
{
    coords [string] choices;

    foreach row, squares in layout {
	foreach index, choice in priorities {
	    if ( choices contains choice ) {
		continue;
	    }
	    int col = squares.index_of( choice );
	    if ( col != -1 ) {
		choices[ choice ] = new coords( beach, row, col );
	    }
	}
    }

    foreach index, choice in priorities {
	if ( choices contains choice ) {
	    return choices[ choice ];
	}
    }

    // This should not be possible
    return new coords( 0, 0, 0 );
}

coords pick_coords_to_comb( int beach, beach_layout layout )
{
    switch ( pick_strategy ) {
    case "first":
	return pick_first_coords_to_comb( beach, layout );
    case "random":
    case "twinkle":
	return pick_random_coords_to_comb( beach, layout );
    }
    abort( "Unknown strategy" );
    return new coords( 0, 0, 0 );
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

int [string] combed_types;
int [item] combed_items;
int combed_meat;
string [int] beachcombings;

beach_layout modify_square( beach_layout layout, coords c, string val )
{
    int row = c.row;
    int col = c.col;

    string squares = layout[ row ];

    buffer modified;
    if ( col > 0 ) {
	modified.append( squares.substring( 0, col ) );
    }
    modified.append( val );
    if ( col < squares.length() - 1 ) {
	modified.append( squares.substring( col + 1, squares.length() ) );
    }

    layout[ row ] = modified;
    return layout;
}

buffer comb_square( coords c, string type )
{
    string cstring = c;
    print( "Combing the square at coordinates " + cstring + " which contains " + type );
    buffer page = visit_url( "choice.php?whichchoice=1388&option=4&coords=" + cstring );

    // Having combed this square, mark it in settings as combed.
    // This is now done by KoLmafia.
    // beach_layout layout = get_beach_layout().modify_square( c, "c" );
    // set_beach_layout( layout );

    return page;
}

buffer comb_beach( buffer page )
{
    void save_page_html( buffer page )
    {
	string filename = my_name() + "_beachcombings_" + now_to_string( "YYYYMMddHHmmssSSS" ) + ".txt";
	print( "Saving page HTML to " + filename, "red" );
	beachcombings[ count( beachcombings ) ] = filename;
	buffer_to_file( page, filename );
    }

    // We depend on KoLmafia to parse the page into properties
    int beach = get_minutes();
    beach_layout layout = get_beach_layout();

    coords c = pick_coords_to_comb( beach, layout );
    string type = code_to_type[ square_at( layout, c ) ];

    // Check if this was a special square
    boolean special = false;

    // Look for beached whales
    if ( page.contains_text( "whale.png" ) ) {
	print( "You found a beached whale!", "red" );
	// Worth noting, but we also want to learn the hover text
	special = true;
    }

    // Look for unknown square types
    if ( type == "?" ) {
	print( "You found an unknown square type!", "red" );
	// Worth noting, and we want to learn everything
	special = true;
    }

    if ( special ) {
	save_page_html( page );
	// For the above, log the page after combing, as well.
	// special = false;
    }

    page = comb_square( c, type );

    // Look for rainbow pearls
    if ( page.contains_text( "rainbow pearl" ) ) {
	print( "You found a rainbow pearl!", "red" );
	// Let's see the the result text
	special = true;
    }

    // Look for meteorite fragments
    if ( page.contains_text( "meteorite fragment" ) ) {
	print( "You found a meteorite fragment!", "red" );
	// Let's see the the result text
	special = true;
    }

    // Look for cursed pirate stuff
    if ( page.contains_text( "cursed pirate cutlass" ) ||
	 page.contains_text( "cursed tricorn hat" ) ||
	 page.contains_text( "cursed swash buckle" ) ) {
	print( "You found a cursed pirate hoard!", "red" );
	// Let's see the the result text
	special = true;
    }

    // Look for messages in bottles
    if ( page.contains_text( "like it contains some sort of message" ) ) {
	print( "You found a message in a bottle!", "red" );
	// Let's see the the result text and learn how to parse out the message.
	special = true;
    }

    if ( special ) {
	save_page_html( page );
    }

    // Count square type
    combed_types[ type ]++;

    // Tally items found
    foreach it, count in page.extract_items() {
	combed_items[ it ] += count;
    }

    combed_meat += page.extract_meat();

    return page;
}

buffer comb_random_beach()
{
    // Wander to a random spot
    buffer page = run_choice( 2 );
    return comb_beach( page );
}

buffer comb_specific_beach( int beach )
{
    buffer page = run_choice( 1, "minutes=" + beach );
    return comb_beach( page );
}

int current_beach = 0;

buffer comb_next_beach()
{
    // Top level control for picking which beach to comb.
    // The comb has been used and the top-level choice is availabe.
    // We can either go to a RANDOM beach, or we can WANDER for a
    // specific number of minutes.
    //
    // Based on pick_strategy
    //  "random"	Go to a new beach every time
    //  "first"		Go to a new beach every time
    //  "specific"	Go to the specifid beach
    //  "twinkle"	Go to a current beach (if any) if
    //			it still has twinkles in it

    buffer page;
    switch ( pick_strategy ) {
    case "specific":
	// Not yet implemented; treat as "random"
    case "random":
    case "first":
	page = comb_random_beach();
    break;
    case "twinkle":
	if ( current_beach == 0 || !get_layout().contains_text( "t" ) ) {
	    page = comb_random_beach();
	    current_beach = get_minutes();
	} else {
	    page = comb_specific_beach( current_beach );
	}
    }

    return page;
}

int beach_comb_free( buffer page )
{
    int beaches_combed = 0;
    while ( page.contains_text( "free walks down the beach" ) ||
	    page.contains_text( "1 free walk down the beach" ) ) {
	page = comb_next_beach();
	beaches_combed++;
    }
    return beaches_combed;
}

int beach_comb_turns( buffer page, int turns )
{
    int beaches_combed = 0;
    while ( my_adventures() > 0 && turns-- > 0 ) {
	page = comb_next_beach();
	beaches_combed++;
    }
    return beaches_combed;
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

void print_help()
{
    print_html("<b>free</b>: comb beach using only free wanders" );
    print_html("<b>all</b>: comb beach using free wanders and all remaining turns" );
    print_html("<b>NUMBER</b>: comb beach using free wanders and specified number of turns" );
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

void main( string command )
{
    if ( available_amount( beach_comb ) == 0 &&
	 available_amount( driftwood_beach_comb ) == 0) {
        abort( "You don't have a Beach Comb or a driftwood beach comb!" );
    }

    int turns =
	command == "free" ? 0 :
	command == "all" ? my_adventures() :
	command.is_integer() ? command.to_int() :
	-1;

    if ( turns < 0 ) {
	print_help();
	exit;
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
    
    try {
	// Use all free combs
	beach_comb_free_only();

	// Optionally spend adventures for more combing
	if ( turns > 0 ) {
	    beach_comb_turns_only( turns );
	}
    } finally {
	print( "" );
	foreach type, count in combed_types {
	    print( "Combed " + type + " " + count + " times." );
	}

	print( "" );
	print( "Items combed:" );
	foreach it, count in combed_items {
	    print( it + " (" + count + ")" );
	}

	if ( combed_meat > 0 ) {
	    print( "" );
	    print( "Meat combed:" + pnum( combed_meat ) );
	}

	if ( count( beachcombings ) > 0 ) {
	    print( "" );
	    print( "Special beach combings saved:", "red" );
	    foreach n, filename in beachcombings {
		print( filename );
	    }
	}
    }
}