///|
/// Convert parsed JSON into a Rego value while preserving exact decimal text.
pub fn Value::from_json(json : @builtin.Json) -> Value? {
  match json {
    Null => Some(Null)
    True => Some(Bool(true))
    False => Some(Bool(false))
    String(text) => Some(String(text))
    @builtin.Json::Number(approximation, repr=representation) => {
      let text = match representation {
        Some(original) => original
        None => approximation.to_string()
      }
      Number::parse(text).map(fn(number) { Number(number) })
    }
    Array(items) => {
      let values : Array[Value] = []
      for item in items {
        guard Value::from_json(item) is Some(value) else { return None }
        values.push(value)
      }
      Some(Array(values))
    }
    Object(fields) => {
      let values : Map[String, Value] = Map([])
      for (key, item) in fields {
        guard Value::from_json(item) is Some(value) else { return None }
        values[key] = value
      }
      Some(Object(values))
    }
  }
}

///|
/// Convert a Rego value to JSON; sets are represented as arrays in JSON output.
pub fn Value::to_json(self : Value) -> @builtin.Json {
  match self {
    Null => @builtin.Json::null()
    Bool(value) => @builtin.Json::boolean(value)
    Number(value) =>
      @builtin.Json::number(
        value.approximate_double(),
        repr=value.to_canonical_string(),
      )
    String(value) => @builtin.Json::string(value)
    Array(values) =>
      @builtin.Json::array(values.map(fn(value) { value.to_json() }))
    Set(values) =>
      @builtin.Json::array(values.map(fn(value) { value.to_json() }))
    Object(fields) => {
      let output : Map[String, @builtin.Json] = Map([])
      for (key, value) in fields {
        output[key] = value.to_json()
      }
      @builtin.Json::object(output)
    }
  }
}
