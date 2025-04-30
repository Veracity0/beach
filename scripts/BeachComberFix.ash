since r27551;

import <BeachComberData.ash>

compact_coords_map common;
coords_list uncommon;
coords_list rare;
coords_list unknown;

// Beaches can contain multiple castles, but unique beaches matter,
// not the coordinates of individual beach tiles
beach_set castle;

// This is what combing with combo looks like:

/*
[19631] Wandering 8322 minutes down the beach
Encounter: Comb the Beach (8322 minutes down the beach)
> Our rare tile is combed, but we found some rough sand. So I guess there's that.
Combing square 5,1 (8322 minutes down the beach)
You acquire an item: taco shell
You acquire grain of sand (2)
*/

// This what combing with old BeachComber looks like

/*
[13930] Wandering to a random section of the beach
Encounter: Comb the Beach (355 minutes down the beach)
> 1 squares in beach 355 contain a beached whale
> 3 squares in beach 355 contain combed sand
> 85 squares in beach 355 contain rough sand
> 1 squares in beach 355 contain rough sand with a twinkle
> You found a beached whale!
> Saving page HTML to Veracity_beachcombings_20200818162017165.txt
> Combing the square at coordinates 2,3548 which contains a beached whale
Combing square 2,3 (355 minutes down the beach)
You gain 11,316,935 Meat
> Saving page HTML to Veracity_beachcombings_20200818162017779.txt
*/

// This what combing with new BeachComber looks like

/*
[24593] Wandering 4067 minutes down the beach
Encounter: Comb the Beach (4067 minutes down the beach)
> 1 squares in beach 4067 contain a beached whale
> 2 squares in beach 4067 contain combed sand
> 77 squares in beach 4067 contain rough sand
> You found a beached whale!
> Saving page HTML to Veracity_4067_3_9_20230823234110454.html
> Combing the square at coordinates (4067,3,9) which contains a beached whale
Combing square 3,9 (4067 minutes down the beach)
You gain 10,723,919 Meat
> (4067,3,9) is a 'rare' tile.
> Saving page HTML to Veracity_4067_3_9_20230823234110636.html
*/

/*
[22206] Wandering 5540 minutes down the beach
Encounter: Comb the Beach (5540 minutes down the beach)
> 6 squares in beach 5540 contain combed sand
> 83 squares in beach 5540 contain rough sand
> 1 squares in beach 5540 contain rough sand with a twinkle
> Combing the square at coordinates (5540,9,5) which contains rough sand with a twinkle
Combing square 9,5 (5540 minutes down the beach)
You acquire an item: cursed pirate cutlass
You acquire hamethyst (5)
You acquire baconstone (5)
You acquire porquoise (5)
You gain 205,406 Meat
> You found a cursed pirate hoard!
> (5540,9,5) is a 'rare' tile.
> Saving page HTML to Veracity_beachcombings_20230819055519801.txt
*/

/*
[238766] Wandering 1163 minutes down the beach
Encounter: Comb the Beach (1163 minutes down the beach)
> 13 squares in beach 1163 contain combed sand
> 76 squares in beach 1163 contain rough sand
> 1 squares in beach 1163 contain rough sand with a twinkle
> 861 rare tiles have already been verified
> 91 unverified rare tiles are candidates for combing
> Combing the square at coordinates (1163,8,2) which contains rough sand with a twinkle
Combing square 8,2 (1163 minutes down the beach)
> You found a message in a bottle!
> (1163,8,2) is a 'rare' tile.
> Saving page HTML to Chondara_1163_8_2_20240415100059439.html
*/


typedef matcher combing_matcher;

combing_matcher create_combing_matcher(string data)
{
    return create_matcher("Combing square (\\d+),(\\d+) \\((\\d+) minutes down the beach\\)\\n(.*?)\\n", data);
}

coords extract_tile(combing_matcher m) {
    int minutes = m.group(3).to_int();
    int row = m.group(1).to_int();
    int column = m.group(2).to_int();
    return new coords(minutes, row, column - 1);
}

rare_type extract_rarity(combing_matcher m) {
    string acquisition = m.group(4);

    if ( acquisition.contains_text("piece of driftwood")) {
	return RARE_DRIFTWOOD;
    }

    if ( acquisition.contains_text( "cursed pirate cutlass" ) ||
	 acquisition.contains_text( "cursed tricorn hat" ) ||
	 acquisition.contains_text( "cursed swash buckle" ) ) {
	return RARE_PIRATE;
    }

    if ( acquisition.contains_text( "meteorite fragment" ) ) {
	return RARE_METEORITE;
    }

    if ( acquisition.contains_text( "rainbow pearl" ) ) {
	return RARE_PEARL;
    }

    if ( acquisition.contains_text("Meat")) {
	return RARE_WHALE;
    }

    if ( acquisition.contains_text("piece of driftwood")) {
	return RARE_DRIFTWOOD;
    }

    if ( acquisition.contains_text( "message in a bottle" ) ) {
	return RARE_MESSAGE;
    }

    return NOT_RARE;
}

int rares_seen = 0;
tile_list[rare_type] tile_rarities;

void process_rares(string data)
{
    void process_rare_combings()
    {
	combing_matcher m = create_combing_matcher(data);
	while (m.find()) {
	    rare_type tile_rarity = m.extract_rarity();
	    if (tile_rarity != NOT_RARE) {
		coords tile = m.extract_tile();
		tile_rarities[tile_rarity].add_tile(tile);
		rares_seen++;
	    }
	}
    }
    process_rare_combings();
}

void print_tile_rarities()
{
    print();
    print("Total rares collected: " + rares_seen);
    foreach type, list in tile_rarities {
	print(type + ": " + count(list));
    }
}

void save_tile_rarities()
{
    driftwood_tiles = tile_rarities[RARE_DRIFTWOOD];
    pirate_tiles = tile_rarities[RARE_PIRATE];
    message_tiles = tile_rarities[RARE_MESSAGE];
    whale_tiles = tile_rarities[RARE_WHALE];
    meteorite_tiles = tile_rarities[RARE_METEORITE];
    pearl_tiles = tile_rarities[RARE_PEARL];
    save_rare_type_data();
}

void process_beach_entry(string log_date, string data)
{
    if (data.length() == 0) {
	return;
    }

    // Count the beaches we visited in this log
    beach_set visited_beaches;
    // Count tiles that we find on each beach
    int commons, uncommons, rares, unknowns, castles, total;

    void process_types()
    {
	// (7902,7,10) is an 'uncommon' tile.
	matcher m = create_matcher("\\((\\d+),(\\d+),(\\d+)\\) is an? '(.*?)' tile", data);
	while (m.find()) {
	    int minutes = m.group(1).to_int();
	    int row = m.group(2).to_int();
	    int column = m.group(3).to_int();
	    string type = m.group(4);
	    coords tile = new coords(minutes, row, column-1);
	    switch (type) {
	    case "common":
		common.add_tile(tile);
		commons++;
		break;
	    case "uncommon":
		uncommon.add_tile(tile);
		uncommons++;
		break;
	    case "rare":
		rare.add_tile(tile);
		rares++;
		break;
	    case "unknown":
		unknown.add_tile(tile);
		unknowns++;
		break;
	    default:
		print(m.group(0));
		break;
	    }
	    total++;
	}
    }

    void process_castles()
    {
	// > 2 squares in beach 7149 contain a sand castle
	matcher m = create_matcher("(\\d+) squares? in beach (\\d+) contain a sand castle", data);
	while (m.find()) {
	    int count =  m.group(1).to_int();
	    int minutes = m.group(2).to_int();
	    castle.add_beach(minutes);
	    castles += count;
	}
    }

    process_types();
    process_castles();

    if (total > 0) {
	print(log_date + " Tiles: " +
	      commons + " common " +
	      uncommons + " uncommon " +
	      rares + " rare " +
	      unknowns + " unknown." +
	      " total = " + total);
    }
    if (count(castle) > 0) {
	print(log_date + " Castles: " +
	      count(castle) + " unique beaches contain " +
	      castles + " sand castles.");
    }
}

void print_new_data()
{
    print();
    print("Tiles processed");
    print();
    print("common: " + common.count_tiles());
    print("uncommon: " + count(uncommon));
    print("rare: " + count(rare));
    print("unknown: " + count(unknown));
    print("sand castles: " + count(castle));
}

void print_castle_beaches()
{
    // castle is the beach_set of castles we saw
    // Make a beach_list from it.
    beach_list seen_castle_beaches = castle;

    // castle_beaches_wiki is the beach_set of derived beaches
    // Make a beach_list from it.
    beach_list derived_castle_beaches = castle_beaches_wiki;

    // Make a new beach_set from the derived castles
    beach_set missing_castle_beaches = derived_castle_beaches;
    
    // Remove the seen castles
    remove_beaches(missing_castle_beaches, seen_castle_beaches);

    // Statistics
    int seen_castle_count = count(castle);
    int derived_castle_count = count(castle_beaches_wiki);
    int missing_castle_count = count(missing_castle_beaches);

    print();
    if (missing_castle_count == 0) {
	print("We have have seen all " + derived_castle_count + " beaches with sand castles.");
	return;
    }
	
    print("We have not seen the following " + missing_castle_count + " beaches with sand castles:");
    foreach b in missing_castle_beaches {
	print("&nbsp;&nbsp;&nbsp;&nbsp;"+ b);
    }
}

void print_tile_summary(string header)
{
    print();
    print(header);
    print();
    print("rare tiles: " + count(rare_tiles));
    print("uncommon_tiles: " + count(uncommon_tiles));
    print("common_tiles: " + common_tiles_map.count_tiles());
}

// The Beach Comb Box was the IOTM for July 2019
// I modernized request logging on Dex 28, 2019 
string earliest_date = "20191229";

// BeachComber was modernized on August 15, 2023
string modern_date = "20230815";

string[int] players;
string date = earliest_date;
string player = "";
boolean rarities = false;
boolean save = false;

void print_help()
{
    string spaces = "&nbsp;&nbsp;&nbsp;&nbsp;";
    print("BeachComberFix DATE [PARAM...]");
    print(spaces + "DATE is the date of the first session log to inspect");
    print(spaces + "(We will inspect all session logs after that up to present)");
    print(spaces + "player=name - look at session log for a single player");
    print(spaces + "(if omitted, take players from beach/players.txt)");
    print(spaces + "(if empty, use current player, if logged in)");
    print(spaces + "rarities - scrape rare tiles combed.");
    print(spaces + "save - after scraping tiles and pruning, save results.");
}

string parse_parameters(string... parameters)
{
    boolean is_valid_date(string param)
    {
	matcher m = create_matcher("(\\d{4})(\\d{2})(\\d{2})", param);
	if (!m.find()) {
	    print("date must be formatted as YYYYMMDD", "red");
	    return false;
	}
	int year = m.group(1).to_int();
	// BeachComber started collecting data in 2023. Do we care?
	if (year < 2023) {
	    print("BeachComber started comllecting data in 2023; no need to process earlier logs", "red");
	    return false;
	}
	int month = m.group(2).to_int();
	if (month < 1 || month > 12) {
	    print("month must be from 1 - 12", "red");
	    return false;
	}
	int day = m.group(3).to_int();
	if (day < 1 || day > 31) {
	    print("day must be from 1 - 31", "red");
	    return false;
	}
	return true;
    }

    void load_players()
    {
	// If user specified a player, use exactly that one.
	if (player != "") {
	    players[0] = player;
	    return;
	}

	// Otherwise, read players.txt
	string all_players = file_to_buffer(beach_file("players.txt")).to_string();
	foreach n, name in all_players.split_string("\n") {
	    if (name != "") {
		players[count(players)] = name;
	    }
	}

	// If we found one or more, cool.
	if (count(players) > 0) {
	    return;
	}

	// If we are logged in, use current player name
	string name = my_name();
	if (name == "") {
	    print("You are not logged in. Which player's sessions should I examine?");
	    exit;
	}

	players[0] = name;
    }

    boolean bogus = false;
    foreach n, param in parameters {
	switch (param) {
	case "":
	    continue;
	case "help":
	    print_help();
	    exit;
	case "rare":
	    rarities = true;
	    continue;
	case "save":
	    save = true;
	    continue;
	}

	if (param.starts_with("player=")) {
	    int index = param.index_of("=");
	    player = param.substring(index + 1);
	    continue;
	}

	matcher date_matcher = create_matcher("(\\d{8})", param);
	if (date_matcher.find()) {
	    if (is_valid_date(param)) {
		date = param;
	    } else {
		// Error message already printed
		bogus = true;
	    }
	    continue;
	}

	print("I don't understand what '" + param + "' means", "red");
	bogus = true;
	continue;
    }

    if (bogus) {
	exit;
    }

    load_players();

    return date;
}

void main(string... parameters)
{
    // Parameters are optional. Depending on how the script is invoked,
    // there may be a single string with space-separated keywords, or
    // multiple strings. Whichever, turn into an array of keywords.
    string[] params = parameters.join_strings(" ").split_string(" ");

    if (params.count() == 0 || params[0] == "help") {
	print_help();
	exit;
    }

    // Parse parameters, if any. Do it before validating the
    // configuration, since parameters can override properties.
    parse_parameters(params);

    // Load existing data
    if (!rarities) {
	load_tile_data(false);
	print_tile_summary("Initial tile data");
	print();
	return;
    }

    foreach n, name in players {
	print("Processing logs for " + name);
	int now = now_to_int();
	int current = date_to_timestamp("yyyyMMdd", date);
	int millis = 24 * 60 * 60 * 1000;
	int tomorrow = now + millis;

	while (current < tomorrow) {
	    string log_date = timestamp_to_date(current, "yyyyMMdd");
	    string[] logs = session_logs(name, log_date, 0);

	    // Process each log
	    foreach n, log in logs {
		// Process the data in it
		if (rarities) {
		    process_rares(log);
		} else {
		    process_beach_entry(log_date, log);
		}
	    }
	    current += millis;
	}
    }

    if (rarities) {
	print_tile_rarities();
	if (save) {
	    save_tile_rarities();
	}
	return;
    }

    // Report on what we scraped
    print_new_data();

    // Report on castles we saw
    print_castle_beaches();
}
