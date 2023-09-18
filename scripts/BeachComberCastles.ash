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
int[] head_castles = {
    9375,	// EVERY
    8482,	// TWENTY
    7479,	// SECOND
    6454,	// LETTER
    5550,	// OF
    4910,	// THE
    4292,	// BOTTLE
    3289,	// MESSAGE
    2264,	// LOOPED
    1151,	// THRICE
};

beach_set derive_castles(string message)
{
    beach_set derived;
    int index = 0;
    int current_head = head_castles[index++];
    int current = current_head;
    derived.add_beach(current);
    for (int i = 0; i < message.length(); ++i) {
	string letter = message.char_at(i);
	// A space starts the next word at a new castle
	if (letter == " ") {
	    current_head = head_castles[index++];
	    current = current_head;
	    derived.add_beach(current);
	    continue;
	}
	// If we are not at first letter of a word, but in a letter break
	if (current != current_head) {
	    current -= 55;
	    derived.add_beach(current);
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
	}
    }
    return derived;
}

beach_set derived_castle_map = derive_castles(decoded_message);
beach_list derived_castles = derived_castle_map;
// save_beaches(derived_castles, "beaches.castle.wiki.json");

print("There are " + count(derived_castles) + " castles encoding the puzzle hint");

// ***************************
//      Castle Decoding      *
// ***************************

string decode_castles(beach_list input)
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

    foreach key, minutes in beaches {
	if (current != 0) {
	    int interval = current - minutes;
	    if (interval % 11 != 0) {
		// Word boundary!
		print_letter();
		message.append(" ");
		current = minutes;
		continue;
	    }
	    if (interval > 55) {
		// This should only happen if we are missing one or more castles
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
print("Decoded message = '" + decode_castles(derived_castles) + "'");

// ***************************
//         Missing Castles   *
// ***************************

// castle_beach_map is beaches we have seen
// derived_castles (beaches 3853 - 9375) encode the hint
// -> any castle < 3853 is for fun, but not part of the hint.
//
// Which castles are we missing from the encoded beaches?

void main(int... params) {
    print("Decoded message from observed castles = '" + decode_castles(castles) + "'");
}
