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
//
// Further spading:
//
// Rare tiles to be verified: 567
// Beaches with no uncommon tiles: 71
//
// I find beaches with no uncommon tiles to be suspicious. Perhaps some
// beaches really have none, but how likely is that? I originally had
// more than 100 beaches with no uncommons, and that number is slowly
// decreasing as I continue to make passes over the entire beach.
//
// When combo visits a beach looking for a rare, if it is unavailable,
// combo will comb a twinkle, expecting an uncommon. With enough combo
// users interfering with my spading ;), by the time I look, there are
// no twinkles left.
//
// Perhaps rare tile hoarders do the same.
//
// In the interest of filling out the set of known uncommons, beaches
// with no known uncommons are of special interest. Perhaps a filter
// option (like "tidal", "unpublished", or "unverified") to prioritize
// visiting those beaches would be useful.

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

void main(string... parameters)
{
    boolean verbose = false;

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

    void load_beach_data()
    {
	rare_tiles = load_tiles("tiles.rare.json");
	rare_tiles_new = load_tiles("tiles.rare.new.json");
	rare_tiles_errors = load_tiles("tiles.rare.errors.json");
	rare_tiles_map.clear();
	rare_tiles_map.add_tiles(rare_tiles);
	rare_tiles_map.add_tiles(rare_tiles_new);
	rare_tiles_map.remove_tiles(rare_tiles_errors);

	rare_tiles_verified = load_tiles("tiles.rare.verified.json");
	rare_tiles_seen = load_tiles("tiles.rare.seen.json");
	verified_tiles_map.clear();
	verified_tiles_map.add_tiles(rare_tiles_verified);
	verified_tiles_map.add_tiles(rare_tiles_seen);

	uncommon_tiles = load_tiles("tiles.uncommon.json");
	uncommon_tiles_new = load_tiles("tiles.uncommon.new.json");
	uncommon_tiles_map.clear();
	uncommon_tiles_map.add_tiles(uncommon_tiles);
	uncommon_tiles_map.add_tiles(uncommon_tiles_new);
    }

    void print_beach_set(beach_set set) {
	foreach b in set {
	    print("&nbsp;&nbsp;&nbsp;&nbsp;" + b);
	}
    }

    load_beach_data();

    // Find all te beaches that we have not seen an uncommon on
    beach_set unknown = all_unknown_uncommon_beaches();
    print(count(unknown).to_string() + " beaches have no known uncommons.");
    if (verbose) {
	print_beach_set(unknown);
    }

    // Find the ones which have a verified rare.
    beach_set verified = unknown_verified_beaches(unknown);
    print(count(verified).to_string() + " beaches with no uncommons have a verified rare tile.");
    if (verbose) {
	print_beach_set(verified);
    }

    // Find the ones which have an unverified rare.
    beach_set unverified = unknown_unverified_beaches(unknown);
    print(count(unverified).to_string() + " beaches with no uncommons have an unverified rare tile.");
    if (verbose) {
	print_beach_set(unverified);
    }

    // Find the ones which are not known to have a rare
    beach_set unrare = unknown_unrare_beaches(unknown);
    print(count(unrare).to_string() + " beaches with no uncommons have no known rare tile.");
    if (verbose) {
	print_beach_set(unrare);
    }
    
}