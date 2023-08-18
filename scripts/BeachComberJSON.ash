typedef string[string] json_object;
typedef json_object[int] json_array;

// This is really simple minded, but adequate for the needs of BeachComber.
//
// JSON objects can have fields which are:
// - integers
// - a single JSON object (do not match opening & closing {})
// - a single JSON array (do not match opening & closing [])
//
// JSON arrays can have fields which are:
// - JSON objects whose fields are all integers
//
// Perhaps the ASH runtime should provide access to a JSON parser, somehow.
// Perhaps ASH should provide a "json" type which is a parsed JSON object

json_object parse_json_object(string json)
{
    json_object result;
    matcher omatcher = create_matcher("\\{(.+)\\}", json);
    if (!omatcher.find()) {
	return result;
    }
    matcher fmatcher = create_matcher("\\\"(.+?)\\\"\\s*?:\\s*\\\"?(\\d+|\\{.+\\}|\\[.+\\])\\\"?,?", omatcher.group(1));
    while (fmatcher.find()) {
	string name = fmatcher.group(1);
	string value = fmatcher.group(2);
	result[name] = value;
    }
    return result;
}

string to_string(json_object object)
{
    return object.to_json();
}

json_array parse_json_array(string json)
{
    json_array result;
    matcher amatcher = create_matcher("\\[(.+)\\]", json);
    if (!amatcher.find()) {
	return result;
    }
    matcher omatcher = create_matcher("\\{(.+?)\\}", amatcher.group(1));
    while (omatcher.find()) {
	json_object object = parse_json_object(omatcher.group(0));
	result[count(result)] = object;
    }
    return result;
}

json_object get_json_object(json_object object, string field)
{
    return parse_json_object(object[field]);
}

json_array get_json_array(json_object object, string field)
{
    return parse_json_array(object[field]);
}

int get_json_int(json_object object, string field)
{
    return object[field].to_int();
}

string get_json_string(json_object object, string field)
{
    return object[field];
}