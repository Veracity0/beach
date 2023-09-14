since r27551;

import <BeachComberData.ash>

load_tile_data(false);

beach_list castles = castle_beach_set;

print("There are " + count(castles) + " beaches with sand castles");

// ***************************
//         Morse Code        *
// ***************************

static
{
    string[string] to_morse = {
        "A" : ".-",
        "B" : "-...",
        "C" : "-.-.",
        "D" : "-..",
        "E" : ".",
        "F" : "..-.",
        "G" : "--.",
        "H" : "....",
        "I" : "..",
        "J" : ".---",
        "K" : "-.-",
        "L" : ".-..",
        "M" : "--",
        "N" : "-.",
        "O" : "---",
        "P" : ".--.",
        "Q" : "--.-",
        "R" : ".-.",
        "S" : "...",
        "T" : "-",
        "U" : ".--",
        "V" : "...-",
        "W" : ".--",
        "X" : "-..-",
        "Y" : "-.--",
        "Z" : "--..",
        "1" : ".----",
        "2" : "..---",
        "3" : "...--",
        "4" : "....-",
        "5" : ".....",
        "6" : "-....",
        "7" : "--...",
        "8" : "---..",
        "9" : "----.",
        "0" : "-----"
    };

    string[string] from_morse;

    foreach key, value in to_morse {
	from_morse[value] = key;
    }
}

// ***************************
//         Wiki Data         *
// ***************************

static string decoded_message = "EVERY TWENTY SECOND LETTER OF THE BOTTLE MESSAGE LOOPED THRICE";
int last_castle_beach = 9375;

beach_set derive_castles(string message)
{
    beach_set derived;
    int current = last_castle_beach;
    derived.add_beach(current);
    // print(current + " = (start)");
    for (int i = 0; i < message.length(); ++i) {
	string letter = message.char_at(i);
	// Space is not encoded, but is in the message, for clarity
	if (letter == " ") {
	    continue;
	}
	string code = to_morse[letter];
	// This should not be possible
	if (code == "") {
	    continue;
	}
	for (int j = 0; j < code.length(); ++j) {
	    string glyph = code.char_at(j);
	    switch(glyph) {
	    case ".":
		current -= 11;
		break;
	    case "-":
		current -= 33;
		break;
	    }
	    derived.add_beach(current);
	    // print(current + " = " + glyph);
	}
	// Put in a letter break
	current -= 55;
	// print(current + " = (break)");
	derived.add_beach(current);
    }
    return derived;
}

beach_set derived_castle_map = derive_castles(decoded_message);
beach_list derived_castles = to_beach_list(derived_castle_map);
// save_beaches(derived_castles, "beaches.castle.wiki.json");

print("There are " + count(derived_castles) + " castles encoding the puzzle hint");

// ***************************
//      Castle Decoding      *
// ***************************

string decode_castles(beach_list input, int skip)
{
    beach_list beaches = copy(input);
    sort beaches by -value;

    buffer code;
    buffer message;
    beach current = 0;

    void print_letter()
    {
	if (code.length() > 0) {
	    string letter = from_morse[code.to_string()];
	    // print(current + " = " + letter);
	    message.append(letter == "" ? "?" : letter);
	    code.set_length(0);
	}
    }

    // Assumptions/heuristics:
    //
    // 1) The distances between "message" beaches is a multiple of 11
    // 2) Potential ambiguity
    // -- 11 beaches = "dot"
    // -- 33 beaches = "dash"
    // --- It could be "dot dot dot" - "S"
    // -- 55 beaches = "end of letter"
    // --- It could be "..-" - not a letter!
    // --- It could be ".-." - not a letter
    // --- It could be "-.." - not a letter
    // --- It could be "....." - "5"
    // If preceded or followed by valid letter, the "not a letters"
    // could resolve into actual letters.
    // 3) Assume that the "complete" solution has no ambiguity
    //
    // 4) If we encounter a distance which is not a multiple of 11:
    // -- If less than 11: didn't miss anything
    // ---  skip it
    // -- If between 12 and 33: did we miss an 11?
    // --- skip it
    // -- If between 34 and 43: did we miss a 3*11 or 33?
    // --- skip it
    // -- If between 44 and 54: did we miss an 11 and a 33? Which order?
    // --- skip it
    // -- Anything greater than 55? all bets are off
    // --- skip it
    //
    // For all or the above, accumulate interval since last valid
    // "message" castle - on a multiple of 11 - and when we find a new
    // "valid" castle, if the interval was greater than 55, print the
    // interval, clear the code, and append "?" to the message.

    foreach key, minutes in beaches {
	if (skip-- > 0) {
	    continue;
	}
	if (current != 0) {
	    int interval = current - minutes;
	    if (interval % 11 != 0) {
		// skip this sand castle
		continue;
	    }
	    if (interval > 55) {
		print(current + "-" + minutes + "=" + interval);
		message.append("?");
		code.set_length(0);
		current = minutes;
		continue;
	    }
	    switch (interval) {
	    case 11:
		code.append(".");
		break;
	    case 22:
		continue;
	    case 33:
		code.append("-");
		break;
	    case 44:
		continue;
	    case 55:
		print_letter();
		break;
	    }
	}
	current = minutes;
    }
    print_letter();

    return message;
}

print("Encoded message = '" + decoded_message + "'");
print("Decoded message = '" + decode_castles(derived_castles, 0) + "'");

// ***************************
//         Missing Castles   *
// ***************************

// castle_beach_map is beaches we have seen
// derived_castles (beaches 3853 - 9375) encode the hint
// -> any castle < 3853 is for fun, but not part of the hint.
//
// Which castles are we missing from the encoded beaches?

void main(int... params) {
    int skip = count(params) > 0 ? params[0] : 0;
    beach_set missing_castles = derived_castles;
    missing_castles.remove_beaches(castles);

    print("There are " + count(missing_castles) + " hint castles that we have not seen yet");
    print("Decoded message from observed castles = '" + decode_castles(castles, skip) + "'");
}
