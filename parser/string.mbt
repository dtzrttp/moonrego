///|
fn hex_digit(unit : UInt16) -> Int32? {
  if unit >= '0' && unit <= '9' {
    Some(unit.to_int() - '0'.to_int())
  } else if unit >= 'a' && unit <= 'f' {
    Some(unit.to_int() - 'a'.to_int() + 10)
  } else if unit >= 'A' && unit <= 'F' {
    Some(unit.to_int() - 'A'.to_int() + 10)
  } else {
    None
  }
}

///|
fn decode_json_string(text : String) -> String? {
  let units : Array[Char] = []
  let mut index = 0
  while index < text.length() {
    let current = text[index]
    if current != '\\' {
      units.push(current.unsafe_to_char())
      index += 1
      continue
    }
    index += 1
    if index >= text.length() {
      return None
    }
    match text[index] {
      '"' => units.push('"')
      '\\' => units.push('\\')
      '/' => units.push('/')
      'b' => units.push(Int32::unsafe_to_char(8))
      'f' => units.push(Int32::unsafe_to_char(12))
      'n' => units.push('\n')
      'r' => units.push('\r')
      't' => units.push('\t')
      'u' => {
        index += 1
        let mut code_point = 0
        for _ in 0..<4 {
          if index >= text.length() {
            return None
          }
          guard hex_digit(text[index]) is Some(digit) else { return None }
          code_point = code_point * 16 + digit
          index += 1
        }
        units.push(code_point.to_uint16().unsafe_to_char())
        continue
      }
      _ => return None
    }
    index += 1
  }
  Some(String::from_array(units))
}
