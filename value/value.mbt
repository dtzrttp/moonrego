///|
pub(all) enum Value {
  Null
  Bool(Bool)
  Number(Number)
  String(String)
  Array(Array[Value])
  Object(Map[String, Value])
  Set(Array[Value])
}

///|
pub fn Value::null() -> Value {
  Null
}

///|
pub fn Value::boolean(value : Bool) -> Value {
  Bool(value)
}

///|
pub fn Value::number(value : Number) -> Value {
  Number(value)
}

///|
pub fn Value::string(value : String) -> Value {
  String(value)
}

///|
pub fn Value::array(values : Array[Value]) -> Value {
  Array(values)
}

///|
pub fn Value::set(values : Array[Value]) -> Value {
  let unique : Array[Value] = []
  for value in values {
    if !unique.any(fn(existing) { existing.equal(value) }) {
      unique.push(value)
    }
  }
  Set(unique)
}

///|
pub fn Value::kind_name(self : Value) -> String {
  match self {
    Null => "null"
    Bool(_) => "boolean"
    Number(_) => "number"
    String(_) => "string"
    Array(_) => "array"
    Object(_) => "object"
    Set(_) => "set"
  }
}

///|
pub fn Value::elements(self : Value) -> Array[Value] {
  match self {
    Array(values) | Set(values) => values.copy()
    _ => []
  }
}

///|
pub fn Value::equal(self : Value, other : Value) -> Bool {
  match (self, other) {
    (Null, Null) => true
    (Bool(left), Bool(right)) => left == right
    (Number(left), Number(right)) => left.equal(right)
    (String(left), String(right)) => left == right
    (Array(left), Array(right)) => {
      if left.length() != right.length() {
        return false
      }
      for i in 0..<left.length() {
        if !left[i].equal(right[i]) {
          return false
        }
      }
      true
    }
    (Set(left), Set(right)) =>
      left.length() == right.length() &&
      left.all(fn(value) { right.any(fn(candidate) { value.equal(candidate) }) })
    (Object(left), Object(right)) => {
      if left.length() != right.length() {
        return false
      }
      for key, value in left {
        guard right.get(key) is Some(other_value) else { return false }
        if !value.equal(other_value) {
          return false
        }
      }
      true
    }
    _ => false
  }
}
