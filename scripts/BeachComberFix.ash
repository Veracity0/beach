since r27551;

import <BeachComberData.ash>

compact_coords_map common;
coords_list uncommon;
coords_list rare;
coords_list unknown;

// Beaches can contain multiple castles, but unique beaches matter,
// not the coordinates of individual beach tiles
beach_set castle;

void process_beach_entry(string log_date, string data)
{
    if (data.length() == 0) {
	return;
    }

    // [32167] Wandering 7149 minutes down the beach
    // Encounter: Comb the Beach (7149 minutes down the beach)
    // > 2 squares in beach 7149 contain a sand castle
    // > 4 squares in beach 7149 contain combed sand
    // > 63 squares in beach 7149 contain rough sand
    // > 1 squares in beach 7149 contain rough sand with a twinkle
    // > 670 rare tiles are too far from the water
    // > 53 rare tiles are candidates for combing
    // > Combing the square at coordinates (7149,8,1) which contains rough sand with a twinkle
    // Combing square 8,1 (7149 minutes down the beach)
    // You acquire an item: sand dollar
    //> (7149,8,1) is an 'uncommon' tile.

    // Ideally, I will match on "entries" like that and extract what I need.

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
    print();
    print("Beaches processed");
    print();
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

void fix_tile_data()
{
    rare_tiles_new.clear();
    rare_tiles_new.add_tiles(rare);

    rare_tiles_seen.clear();
    rare_tiles_seen.add_tiles(rare);

    uncommon_tiles_new.clear();
    uncommon_tiles_new.add_tiles(uncommon);

    common_tiles_new_map.clear();
    common_tiles_new_map.add_tiles(common);

    castle_beaches_seen.clear();
    castle_beaches_seen = castle;
}

void print_tile_summary(string header)
{
    print();
    print(header);
    print();
    print("rare tiles: " + count(rare_tiles));
    print("new rare tiles: " + count(rare_tiles_new));
    print("verified_rare_tiles: " + count(rare_tiles_verified));
    print("seen_rare_tiles: " + count(rare_tiles_seen));
    print("uncommon_tiles: " + count(uncommon_tiles));
    print("new uncommon_tiles: " + count(uncommon_tiles_new));
    print("common_tiles: " + common_tiles_map.count_tiles());
    print("new common_tiles: " + common_tiles_new_map.count_tiles());
    print("castle_beaches: " + count(castle_beaches));
    print("castle_beaches_seen: " + count(castle_beaches_seen));
}

string[int] players;
string date = "20230815";
string player = "";
boolean commons = true;
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
    print(spaces + "commons - scrape commonsafter scraping tiles and pruning, save results.");
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
	case "commons":
	    commons = true;
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
    load_tile_data(false);
    print_tile_summary("Initial tile data");
    print();

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
		process_beach_entry(log_date, log);
	    }
	    current += millis;
	}
    }

    // Report on what we scraped
    print_new_data();

    // Report on castles we saw
    print_castle_beaches();

    // Fix the tile data based on what we scraped
    fix_tile_data();
    print_tile_summary("Processed tile data");

    // Prune existing data from the known data
    print();
    prune_tile_data(true, save);
    // *** temporary for populating initial map of commons
    // if (commons) {
    //	   common_tiles_new_map.save_tiles_map("tiles.common.new.json");
    // }
    print_tile_summary("Pruned tile data");
}
since r27551;

import <BeachComberData.ash>

compact_coords_map common;
coords_list uncommon;
coords_list rare;
coords_list unknown;

// Beaches can contain multiple castles, but unique beaches matter,
// not the coordinates of individual beach tiles
beach_set castle;

void process_beach_entry(string log_date, string data)
{
    if (data.length() == 0) {
	return;
    }

    // [32167] Wandering 7149 minutes down the beach
    // Encounter: Comb the Beach (7149 minutes down the beach)
    // > 2 squares in beach 7149 contain a sand castle
    // > 4 squares in beach 7149 contain combed sand
    // > 63 squares in beach 7149 contain rough sand
    // > 1 squares in beach 7149 contain rough sand with a twinkle
    // > 670 rare tiles are too far from the water
    // > 53 rare tiles are candidates for combing
    // > Combing the square at coordinates (7149,8,1) which contains rough sand with a twinkle
    // Combing square 8,1 (7149 minutes down the beach)
    // You acquire an item: sand dollar
    //> (7149,8,1) is an 'uncommon' tile.

    // Ideally, I will match on "entries" like that and extract what I need.

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
    print();
    print("Beaches processed");
    print();
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

void fix_tile_data()
{
    rare_tiles_new.clear();
    rare_tiles_new.add_tiles(rare);

    rare_tiles_seen.clear();
    rare_tiles_seen.add_tiles(rare);

    uncommon_tiles_new.clear();
    uncommon_tiles_new.add_tiles(uncommon);

    common_tiles_new_map.clear();
    common_tiles_new_map.add_tiles(common);

    castle_beaches_seen.clear();
    castle_beaches_seen = castle;
}

void print_tile_summary(string header)
{
    print();
    print(header);
    print();
    print("rare tiles: " + count(rare_tiles));
    print("new rare tiles: " + count(rare_tiles_new));
    print("verified_rare_tiles: " + count(rare_tiles_verified));
    print("seen_rare_tiles: " + count(rare_tiles_seen));
    print("uncommon_tiles: " + count(uncommon_tiles));
    print("new uncommon_tiles: " + count(uncommon_tiles_new));
    print("common_tiles: " + common_tiles_map.count_tiles());
    print("new common_tiles: " + common_tiles_new_map.count_tiles());
    print("castle_beaches: " + count(castle_beaches));
    print("castle_beaches_seen: " + count(castle_beaches_seen));
}

string[int] players;
string date = "20230815";
string player = "";
boolean commons = true;
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
    print(spaces + "commons - scrape commonsafter scraping tiles and pruning, save results.");
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
	case "commons":
	    commons = true;
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
    load_tile_data(false);
    print_tile_summary("Initial tile data");
    print();

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
		process_beach_entry(log_date, log);
	    }
	    current += millis;
	}
    }

    // Report on what we scraped
    print_new_data();

    // Report on castles we saw
    print_castle_beaches();

    // Fix the tile data based on what we scraped
    fix_tile_data();
    print_tile_summary("Processed tile data");

    // Prune existing data from the known data
    print();
    prune_tile_data(true, save);
    // *** temporary for populating initial map of commons
    // if (commons) {
    //	   common_tiles_new_map.save_tiles_map("tiles.common.new.json");
    // }
    print_tile_summary("Pruned tile data");
}
