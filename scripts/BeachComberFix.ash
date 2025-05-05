since r27551;

import <BeachComberData.ash>

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
> Saving page HTML to Veracity_5540_9_5_20230819055519801.txt
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

string extract_acquisition(combing_matcher m) {
    return m.group(4);
}

rare_type extract_rarity(combing_matcher m) {
    string acquisition = m.extract_acquisition();

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

// The Beach Comb Box was the IOTM for July 2019

// I modernized request logging on Dex 28, 2019 
string earliest_date = "20191229";

// BeachComber was modernized on August 15, 2023
string modern_date = "20230815";

string[int] players;
string date = earliest_date;
string player = "";
boolean verbose = false;
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
    print(spaces + "verbose - verbose logging, as appropriate.");
    print(spaces + "save - after scraping tiles, save results.");
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
	case "verbose":
	    verbose = true;
	    continue;
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

    int total_logs;

    foreach n, name in players {
	print("Processing logs for " + name + "...");
	int now = now_to_int();
	int current = date_to_timestamp("yyyyMMdd", date);
	int millis = 24 * 60 * 60 * 1000;
	int tomorrow = now + millis;

	int player_logs = 0;

	while (current < tomorrow) {
	    string log_date = timestamp_to_date(current, "yyyyMMdd");
	    string[] logs = session_logs(name, log_date, 0);

	    // Process each log
	    foreach n, log in logs {
		// Combing square 2,2 (7307 minutes down the beach)
		// Preference _freeBeachWalksUsed changed from 2 to 3
		// You acquire an item: driftwood bracelet

		matcher pref_matcher = create_matcher("Preference .*?\n", log);
		log = pref_matcher.replace_all("");

		// Process the data in it
		if (rarities) {
		    process_rares(log);
		}

		player_logs++;
	    }
	    current += millis;
	}

	if (verbose) {
	    print(player_logs + " processed for " + name);
	}

	total_logs += player_logs;
    }

    if (verbose & count(players) > 1) {
	print(total_logs + " total logs processed");
    }

    print("Done!");

    if (rarities) {
	print_tile_rarities();
	if (save) {
	    save_tile_rarities();
	}
	return;
    }
}
