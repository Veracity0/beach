since r27551;

import <BeachComberData.ash>

coords_list common;
coords_list uncommon;
coords_list rare;
coords_list unknown;

void process_tile_data(string data)
{
    if (data.length() == 0) {
	return;
    }

    // (7902,7,10) is an 'uncommon' tile.
    matcher m = create_matcher("\\((\\d+),(\\d+),(\\d+)\\) is an? '(.*?)' tile", data);
    int commons, uncommons, rares, unknowns, total;
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
    if (total > 0) {
	print("Tiles found: " +
	      commons + " common " +
	      uncommons + " uncommon " +
	      rares + " rare " +
	      unknowns + " unknown." + " total = " + total);
    }
}

void print_new_data()
{
    print();
    print("Tiles processed");
    print();
    print("common: " + count(common));
    print("uncommon: " + count(uncommon));
    print("rare: " + count(rare));
    print("unknown: " + count(unknown));
}

void fix_tile_data()
{
    rare_tiles_new.clear();
    rare_tiles_new.add_tiles(rare);

    rare_tiles_seen.clear();
    rare_tiles_seen.add_tiles(rare);

    uncommon_tiles_new.clear();
    uncommon_tiles_new.add_tiles(uncommon);
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
}

string[int] players;
string player = "";
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
    print(spaces + "save - after scraping tiles and pruning, save results.");
}

void parse_parameters(string... parameters)
{
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
	case "save":
	    save = true;
	    continue;
	}

	if (param.starts_with("player=")) {
	    int index = param.index_of("=");
	    player = param.substring(index + 1);
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
}

void main(string date, string... parameters)
{
    if (date == "help") {
	print_help();
	exit;
    }

    // Parameters are optional. Depending on how the script is invoked,
    // there may be a single string with space-separated keywords, or
    // multiple strings. Whichever, turn into an array of keywords.
    string[] params = parameters.join_strings(" ").split_string(" ");

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

	while (current < now) {
	    string log_date = timestamp_to_date(current, "yyyyMMdd");
	    string[] logs = session_logs(name, log_date, 0);

	    // Process each log
	    foreach n, log in logs {
		// Process the data in it
		process_tile_data(log);
	    }
	    current += millis;
	}
    }

    // Report on what we scraped
    print_new_data();

    // Fix the tile data based on what we scraped
    fix_tile_data();
    print_tile_summary("Processed tile data");

    // Prune existing data from the known data
    print();
    prune_tile_data(false, save);
    print_tile_summary("Pruned tile data");
}
