since r27551;

import <BeachComberData.ash>

// We track all tiles with "rare" or "uncommon" tiles.
//
// As of 12 Nov 2023, Veracity (including multis) has seen:
//
// Rare tiles from combo: 862
// New: 43
// Errors: 1
// Total: 902
//
// Verified: 216
// New: 119
// Total: 335
//
// Uncommon tiles: 46228
// New: 1407
// Total: 47635
///
// Beaches with rare tiles: 858
// Verified: 328
//
// Beaches with uncommon tiles: 9929
//
// Beaches with sand castles (derived): 180
// Verified: 180

// ***************************
// *       Tile Data         *
// ***************************

// Each segment of the beach (from 1 to 10,000 minutes of wandering)
// contains 10 rows of 10 tiles each. I refer to a segment as a "beach".

// Tiles are of six types:

record tile_data
{
    // Every tile should be one of the following
    int rares;
    int uncommons;
    int commons;
    int heads;
    int castles;
    int combed;
};

// That data structure can be used in multiple ways:
//
// Aggregate 10 tiles in a row
// Aggregate 10 rows in a beach
// Aggregate 10,000 beaches for the total

// Make a copy tyhat you can modify as desired
tile_data copy(tile_data orig)
{
    tile_data result;
    result.rares = orig.rares;
    result.uncommons = orig.uncommons;
    result.commons = orig.commons;
    result.heads = orig.heads;
    result.castles = orig.castles;
    result.combed = orig.combed;
    return result;
}

// Add another tile_data into a source
void add(tile_data result, tile_data two)
{
    result.rares += two.rares;
    result.uncommons += two.uncommons;
    result.commons += two.commons;
    result.heads += two.heads;
    result.castles += two.castles;
    result.combed += two.combed;
}

buffer tile_data_header(buffer table, boolean rows)
{
    table.append("<tr>");
    if (rows) {
	table.append("<th>row</th>");
    } else {
	table.append("<th>minutes</th>");
    }
    table.append("<th>rare</th>");
    table.append("<th>(combed)</th>");
    table.append("<th>uncommon</th>");
    table.append("<th>common</th>");
    table.append("<th>head</th>");
    table.append("<th>castle</th>");
    table.append("</tr>");
    return table;
}

buffer to_html(tile_data data, int id, boolean header, boolean rows, buffer table)
{
    void add_row(int row)
    {
	table.append("<tr>");
	table.append("<td>");
	table.append(id);
	table.append("</td>");
	table.append("<td>");
	table.append(data.rares);
	table.append("</td>");
	table.append("<td>");
	table.append(data.combed);
	table.append("</td>");
	table.append("<td>");
	table.append(data.uncommons);
	table.append("</td>");
	table.append("<td>");
	table.append(data.commons);
	table.append("</td>");
	table.append("<td>");
	table.append(data.heads);
	table.append("</td>");
	table.append("<td>");
	table.append(data.castles);
	table.append("</td>");
	table.append("</tr>");
    }

    if (header) {
	table.append("<html>");
	table.append("<table border=1>");
	table.tile_data_header(rows);
    }

    add_row(id);

    if (header) {
	table.append("</table>");
	table.append("</html>");
    }

    return table;
}

buffer to_html(tile_data data, int id, boolean header, boolean rows)
{
    buffer table;
    return data.to_html(id, header, rows, table);
}

// One useful representation of a "beach" is as an array of 10 rows,
// numbered from 1 to 10. 1 is closest to the water and 10 is farthest
// away. Rows 1 to 4 can be covered by the tides.

typedef tile_data[int] beach_data;

// Examine tile data and generate the beach_data for a single beach
beach_data beach_rows(int minutes)
{
    beach_data result;
    // Inspect each row on this beach
    for (int row = 10; row > 0; row--) {
	tile_data tiles = result[row];
	// Inspect each column on this beach
	for (int column = 0; column < 10; column++) {
	    // Combed tiles also appear in the rare map
	    if (combed_tiles_map.contains_tile(minutes, row, column)) {
		tiles.combed++;
	    }

	    if (rare_tiles_map.contains_tile(minutes, row, column)) {
		tiles.rares++;
	    } else if (uncommon_tiles_map.contains_tile(minutes, row, column)) {
		tiles.uncommons++;
	    } else if (all_common_tiles_map.contains_tile(minutes, row, column)) {
		tiles.commons++;
	    } else if (beach_head_map.contains_tile(minutes, row, column)) {
		tiles.heads++;
	    } else if (castle_tiles_map.contains_tile(minutes, row, column)) {
		tiles.castles++;
	    }
	}
    }
    return result;
}

// Sum the rows into a tile_data for a single beach
tile_data total(beach_data data)
{
    tile_data result;
    foreach row, td in data {
	result.add(td);
    }
    return result;
}

buffer to_html(beach_data data, int id)
{
    buffer table;

    void add_row(int row)
    {
	table.append("<tr>");
	table.append("<td>");
	table.append(row);
	table.append("</td>");
	table.append("<td>");
	table.append(data[row].rares);
	table.append("</td>");
	table.append("<td>");
	table.append(data[row].combed);
	table.append("</td>");
	table.append("<td>");
	table.append(data[row].uncommons);
	table.append("</td>");
	table.append("<td>");
	table.append(data[row].commons);
	table.append("</td>");
	table.append("<td>");
	table.append(data[row].heads);
	table.append("</td>");
	table.append("<td>");
	table.append(data[row].castles);
	table.append("</td>");
	table.append("</tr>");
    }

    table.append("<html>");
    table.append("<table border=1>");
    table.append("<caption>");
    table.append("Beach ");
    table.append(to_int(id));
    table.append("</caption>");

    table.tile_data_header(true);
    for (int row = 10; row > 0; row--) {
	add_row(row);
    }

    table.append("</table>");
    table.append("</html>");

    return table;
}

// ***************************
// *     Beach Detail        *
// ***************************

// Each segment of the beach (from 1 to 10,000 minutes of wandering)
// contains 10 rows of 10 tiles each. I refer to a segment as a "beach".

typedef string[int] row_detail;
typedef row_detail[int] beach_spec;

// Examine tile data and generate the beach_detail for a single beach
beach_spec beach_detail(int minutes)
{
    beach_spec result;
    // Inspect each row on this beach
    for (int row = 10; row > 0; row--) {
	row_detail tiles = result[row];
	// Inspect each column on this beach
	for (int column = 0; column < 10; column++) {
	    string tile;
	    if (combed_tiles_map.contains_tile(minutes, row, column)) {
		tile = "combed";
	    } else if (rare_tiles_map.contains_tile(minutes, row, column)) {
		tile = "rare";
	    } else if (uncommon_tiles_map.contains_tile(minutes, row, column)) {
		tile = "uncom";
	    } else if (all_common_tiles_map.contains_tile(minutes, row, column)) {
		tile = "com";
	    } else if (beach_head_map.contains_tile(minutes, row, column)) {
		tile = "head";
	    } else if (castle_tiles_map.contains_tile(minutes, row, column)) {
		tile = "castle";
	    }
	    tiles[column + 1] = tile;
	}
    }
    return result;
}

buffer to_html(beach_spec data, int id)
{
    buffer table;

    void add_header()
    {
	table.append("<tr>");
	table.append("<th>");
	table.append(id);
	table.append("</th>");
	for (int col = 1; col <= 10; ++col) {
	    table.append("<th>");
	    table.append(col);
	    table.append("</th>");
	}
	table.append("</tr>");
    }

    void add_row(int row)
    {
	row_detail tiles = data[row];
	table.append("<tr>");
	table.append("<td>");
	table.append(row);
	table.append("</td>");
	for (int col = 1; col <= 10; ++col) {
	    table.append("<td>");
	    table.append(data[row, col]);
	    table.append("</td>");
	}
	table.append("</tr>");
    }

    table.append("<html>");
    table.append("<table border=1>");

    add_header();
    for (int row = 10; row > 0; row--) {
	add_row(row);
    }

    table.append("</table>");
    table.append("</html>");

    return table;
}

// ***************************
//     Describe One Beach    *
// ***************************

void describe_beach(int minutes, boolean verbose)
{

    // Beaches depend on common tile data
    parse_commons = true;
    load_tile_data(false);

    // Blank line between loading messages and table
    print();

    // Construct an HTML table
    buffer result;

    if (verbose) {
	// If verbose, we want to see all the rows
	// Fetch the detailed row data for this beach
	beach_spec data = beach_detail(minutes);
	result = data.to_html(minutes);
    } else {
	// Otherwise, we want to see a summary
	// Fetch the row summaries for this beach
	beach_data data = beach_rows(minutes);
	tile_data sum = data.total();
	result = sum.to_html(minutes, true, false);
    }
    print_html(result);
}

// ***************************
//     Spading Completeness  *
// ***************************


// Since we have no seen every beach with tides=0, only combed tiles are unknown
// This record has the numeric state and a set of beaches which are not fully spaded.

record beach_state
{
    tile_data state;
    beach_set castle;
    beach_set combed;
};

beach_state copy(beach_state orig)
{
    beach_state result;
    result.state = orig.state.copy();
    result.castle = orig.castle.to_beach_set();
    result.combed = orig.combed.to_beach_set();
    return result;
}

void add(beach_state result, beach_state two)
{
    result.state.add(two.state);
    result.castle.add_beaches(two.castle);
    result.combed.add_beaches(two.combed);
}

void add_tiles(beach_state sum, tile_data data, int minute)
{
    sum.state.add(data);
    if (data.castles > 0) {
	sum.castle.add_beach(minute);
    }
    if (data.combed > 0) {
	sum.combed.add_beach(minute);
    }
}

// Data for each row
typedef beach_state[int] row_states;

buffer to_html(row_states array)
{
    buffer table;

    void open_table()
    {
	table.append("<html>");
	table.append("<table border=1>");
    }

    void close_table()
    {
	table.append("</table>");
	table.append("</html>");
    }
	    
    void add_header()
    {
	table.append("<tr>");
	table.append("<th>row</th>");
	table.append("<th>rare</th>");
	table.append("<th>(combed</th>");
	table.append("<th>#)</th>");
	table.append("<th>uncommon</th>");
	table.append("<th>common</th>");
	table.append("<th>head</th>");
	table.append("<th>castle</th>");
	table.append("<th>#</th>");
	table.append("</tr>");
    }

    void add_row(int row)
    {
	beach_state data = array[row];

	table.append("<tr>");
	table.append("<td>");
	table.append(to_string(row));
	table.append("</td>");
	table.append("<td>");
	table.append(data.state.rares);
	table.append("</td>");
	table.append("<td>");
	table.append(data.state.combed);
	table.append("</td>");
	table.append("<td>");
	table.append(to_int(count(data.combed)));
	table.append("</td>");
	table.append("<td>");
	table.append(data.state.uncommons);
	table.append("</td>");
	table.append("<td>");
	table.append(data.state.commons);
	table.append("</td>");
	table.append("<td>");
	table.append(data.state.heads);
	table.append("</td>");
	table.append("<td>");
	table.append(data.state.castles);
	table.append("</td>");
	table.append("<td>");
	table.append(to_int(count(data.castle)));
	table.append("</td>");
	table.append("</tr>");
    }

    open_table();
    add_header();
    for (int row = 10; row > 0; row--) {
	add_row(row);
    }
    close_table();

    return table;
}

row_states build_row_data(boolean verbose)
{
    row_states row_data;

    // Sanity check: there should be 1,000,000 tiles tallied
    int rares = 0;
    int uncommons = 0;
    int commons = 0;
    int heads = 0;
    int castles = 0;
    int combed = 0;
    int unverified = 0;

    // 10,000 beaches each with 100 rows
    // tile_data [int, int] beach_rows;

    print();
    print("Iterating over 10,000 beaches, 10 rows, 10 columns");
    for (beach minute = 1; minute <= 10000; minute++) {
	// Inspect each row on this beach
	for (int row = 10; row > 0; row--) {
	    beach_state state = row_data[row];
	    tile_data tiles;
	    // Inspect each column on this beach
	    for (int column = 0; column < 10; column++) {
		// Tiles that _I_ have only seen as combed.
		// We assume they are unverified rares
		// Therefore "unverified" SHOULD equal "combed"
		if (combed_tiles_map.contains_tile(minute, row, column)) {
		    tiles.combed++;
		    combed++;
		}

		if (rare_tiles_map.contains_tile(minute, row, column)) {
		    // All combed tiles are also in the rare map
		    tiles.rares++;
		    rares++;
		    if (!verified_tiles_map.contains_tile(minute, row, column)) {
			unverified++;
		    }
		} else if (uncommon_tiles_map.contains_tile(minute, row, column)) {
		    tiles.uncommons++;
		    uncommons++;
		} else if (beach_head_map.contains_tile(minute, row, column)) {
		    tiles.heads++;
		    heads++;
		} else if (castle_tiles_map.contains_tile(minute, row, column)) {
		    tiles.castles++;
		    castles++;
		} else if (all_common_tiles_map.contains_tile(minute, row, column)) {
		    tiles.commons++;
		    commons++;
		}
	    }
	    // Save the data for this beach row
	    // beach_rows[minute, row] = state;
	    state.add_tiles(tiles, minute);
	}
    }

    if (verbose) {
	print();
	print("Total rares = " + rares);
	print("(Unverified rares = " + unverified + ")");
	print("Total uncommons = " + uncommons);
	print("Total commons = " + commons);
	print("Total beach heads = " + heads);
	print("Total sand castles = " + castles);
	print("Total combed = " + combed);
	print("Total: " + (rares + uncommons + commons + castles + heads));
	print();
    }

    return row_data;
}

row_states derive_tidal_data(row_states row_data)
{
    row_states tidal_data;

    print();
    print("Accumulating tidal data for 10 rows");
    for (int row = 10; row > 0; row--) {
	beach_state current = row_data[row];
	tidal_data[row] = current.copy();
	if (row < 10) {
	    tidal_data[row].add(tidal_data[row + 1]);
	}
    }

    return tidal_data;
}

void analyze_completeness(boolean verbose)
{
    void print_beach_set(beach_set set) {
	foreach b in set {
	    print("&nbsp;&nbsp;&nbsp;&nbsp;" + b);
	}
    }

    // Completeness analysis depends on common tiles
    parse_commons = true;
    load_tile_data(false);

    // Total up known and unknown tiles for each row
    row_states row_data = build_row_data(true);

    print();
    print_html(row_data.to_html());

    // Accumulate known/unknown tiles for each tide level
    row_states tidal_data = derive_tidal_data(row_data);

    // Report on what we found
    print();
    print_html(tidal_data.to_html());
}

// Exported function for use in BeachComber:
// Given already loaded, tile data,
// Return the tidal data to see which beaches need spading
row_states calculate_tidal_data()
{
    return build_row_data(false).derive_tidal_data();
}

// ***************************
//    Beach Set utilities    *
// ***************************

// There are 10,000 beaches

beach_set all_beaches()
{
    beach_set all;
    for i from 1 upto 10000 {
	all[i] = true;
    }
    return all;
}

// Given a beach_set, which beaches are NOT represented?

beach_set unvisited_beaches( beach_set input )
{
    beach_set all = all_beaches();
    remove_beaches(all, input);
    return all;
}

// Given a beach_set, which are NOT in another set?

beach_set excluded_beaches( beach_set input, beach_set test )
{
    // Make a copy of input so caller can use it elsewhere
    beach_set result = input.to_beach_set();
    result.remove_beaches(test);
    return result;
}

// Given a beach_set, which are in another set?

beach_set included_beaches( beach_set input, beach_set test )
{
    // Make a copy of input so caller can use it elsewhere
    beach_set result = input.to_beach_set();
    beach_set excluded = input.excluded_beaches(test);
    result.remove_beaches(excluded);
    return result;
}

// ***************************
//     Uncommon Beaches      *
// ***************************

beach_set all_unknown_uncommon_beaches()
{
    beach_set uncommon_beaches = all_beaches();
    beach_set excluded = to_beach_set(uncommon_tiles_map);
    uncommon_beaches.remove_beaches(excluded);
    return uncommon_beaches;
}

beach_set unknown_verified_beaches(beach_set input)
{
    beach_set included = to_beach_set(verified_tiles_map);
    return input.included_beaches(included);
}

beach_set unknown_unverified_beaches(beach_set input)
{
    beach_set included = to_beach_set(rare_tiles_map);
    beach_set excluded = to_beach_set(verified_tiles_map);
    return input.included_beaches(included).excluded_beaches(excluded);
}

beach_set unknown_unrare_beaches(beach_set input)
{
    beach_set excluded = to_beach_set(rare_tiles_map);
    return input.excluded_beaches(excluded);
}

// ***************************
//       Combed Tiles        *
// ***************************

void generate_combed_tiles(boolean save, boolean verbose)
{
    void print_tiles(compact_coords_map map)
    {
	foreach min, row, col in map {
	    print("&nbsp;&nbsp;&nbsp;&nbsp;(" + min + "," + row + "," + (col + 1) + ")");
	}
    }

    // Since combed tiles are assumed to be unverified rares, all we
    // really need are rare_tiles_map and verified_tiles_map

    parse_commons = false;
    load_tile_data(false);

    int original_beaches = combed_tiles_map.count_beaches();
    int original_tiles = combed_tiles_map.count_tiles();

    compact_coords_map new_combed_tiles_map;
    new_combed_tiles_map.add_tiles(rare_tiles);
    new_combed_tiles_map.remove_tiles(rare_tiles_verified);

    int new_beaches = new_combed_tiles_map.count_beaches();
    int new_tiles = new_combed_tiles_map.count_tiles();

    if (original_tiles != new_tiles) {
	print("Combed tiles: " + original_tiles + " -> " + new_tiles);
	print("Combed beaches: " + original_beaches + " -> " + new_beaches);

	if (save) {
	    save_tiles_map(new_combed_tiles_map, "tiles.combed.json");
	}
    } else {
	print("There " +
	      (original_tiles == 1 ? "is " : "are ") +
	      original_tiles +
	      " combed " +
	      (original_tiles == 1 ? "tile on " : "tiles on ") +
	      original_beaches +
	      (original_beaches == 1 ? " beach." : " beaches."));
    }

    if (new_tiles > 0 && verbose) {
	    print_tiles(combed_tiles_map);
    }
    
}

// ***************************
//      Master Control       *
// ***************************

void main(string... parameters)
{
    boolean verbose = false;
    boolean combed = false;
    boolean complete = false;
    beach minutes = 0;
    boolean save = false;

    void parse_parameters(string... parameters)
    {
	boolean bogus = false;
	foreach n, param in parameters {
	    switch (param) {
	    case "":
		continue;
	    case "verbose":
		verbose = true;
		continue;
	    case "save":
		save = true;
		continue;
	    case "combed":
		combed = true;
		parse_commons = true;
		continue;
	    case "complete":
		complete = true;
		parse_commons = true;
		continue;
	    }

	    if (param.starts_with("minutes=")) {
		// Describe what we know about a particular beach.
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
		continue;
	    }

	    print("I don't understand what '" + param + "' means", "red");
	    bogus = true;
	    continue;
	}

	if (bogus) {
	    exit;
	}
    }

    // Parameters are optional. Depending on how the script is invoked,
    // there may be a single string with space-separated keywords, or
    // multiple strings. Whichever, turn into an array of keywords.
    string[] params = parameters.join_strings(" ").split_string(" ");

    // Parse parameters
    parse_parameters(params);

    if (combed) {
	generate_combed_tiles(save, verbose);
	return;
    }

    if (complete) {
	analyze_completeness(verbose);
	return;
    }

    if (minutes != 0) {
	describe_beach(minutes, verbose);
	return;
    }
}
