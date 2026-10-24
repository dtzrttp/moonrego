///|
/// An exact finite decimal represented as coefficient × 10^-scale.
pub struct Number {
  coefficient : @bigint.BigInt
  scale : Int32
}

///|
fn pow10(exponent : Int32) -> @bigint.BigInt {
  let ten = @bigint.BigInt::from_int(10)
  for value = @bigint.BigInt::from_int(1), i = 0; i < exponent; {
    continue value * ten, i + 1
  } nobreak {
    value
  }
}

///|
fn normalize(coefficient : @bigint.BigInt, scale : Int32) -> Number {
  if coefficient.is_zero() {
    return { coefficient, scale: 0, }
  }
  let ten = @bigint.BigInt::from_int(10)
  for value = coefficient, current_scale = scale; current_scale > 0 &&
     (value % ten).is_zero(); {
    continue value / ten, current_scale - 1
  } nobreak {
    { coefficient: value, scale: current_scale, }
  }
}

///|
fn is_digit(c : UInt16) -> Bool {
  c >= '0' && c <= '9'
}

///|
pub fn Number::parse(text : String) -> Number? {
  let length = text.length()
  if length == 0 {
    return None
  }
  let mut index = 0
  let mut negative = false
  if text[index] == '-' {
    negative = true
    index += 1
    if index == length {
      return None
    }
  }
  let integer_start = index
  if text[index] == '0' {
    index += 1
    if index < length && is_digit(text[index]) {
      return None
    }
  } else if text[index] >= '1' && text[index] <= '9' {
    while index < length && is_digit(text[index]) {
      index += 1
    }
  } else {
    return None
  }
  let integer_digits = text[integer_start:index].to_owned()
  let mut fraction_digits = ""
  if index < length && text[index] == '.' {
    index += 1
    let fraction_start = index
    while index < length && is_digit(text[index]) {
      index += 1
    }
    if index == fraction_start {
      return None
    }
    fraction_digits = text[fraction_start:index].to_owned()
  }
  let mut exponent = 0
  if index < length && (text[index] == 'e' || text[index] == 'E') {
    index += 1
    let mut exponent_negative = false
    if index < length && (text[index] == '+' || text[index] == '-') {
      exponent_negative = text[index] == '-'
      index += 1
    }
    let exponent_start = index
    while index < length && is_digit(text[index]) {
      let digit = text[index].to_int() - ('0' : UInt16).to_int()
      if exponent > 10000 {
        return None
      }
      exponent = exponent * 10 + digit
      index += 1
    }
    if index == exponent_start {
      return None
    }
    if exponent_negative {
      exponent = -exponent
    }
  }
  if index != length {
    return None
  }
  let digits = integer_digits + fraction_digits
  let mut coefficient = @bigint.BigInt::from_string(digits)
  if negative {
    coefficient = -coefficient
  }
  let mut scale = fraction_digits.length() - exponent
  if scale < 0 {
    coefficient = coefficient * pow10(-scale)
    scale = 0
  }
  if scale > 10000 {
    return None
  }
  Some(normalize(coefficient, scale))
}

///|
fn Number::aligned(
  self : Number,
  other : Number,
) -> (@bigint.BigInt, @bigint.BigInt, Int32) {
  let scale = if self.scale >= other.scale { self.scale } else { other.scale }
  (
    self.coefficient * pow10(scale - self.scale),
    other.coefficient * pow10(scale - other.scale),
    scale,
  )
}

///|
pub fn Number::equal(self : Number, other : Number) -> Bool {
  self.coefficient == other.coefficient && self.scale == other.scale
}

///|
pub fn Number::compare(self : Number, other : Number) -> Int32 {
  let (left, right, _) = self.aligned(other)
  left.compare(right)
}

///|
pub fn Number::add(self : Number, other : Number) -> Number {
  let (left, right, scale) = self.aligned(other)
  normalize(left + right, scale)
}

///|
pub fn Number::subtract(self : Number, other : Number) -> Number {
  let (left, right, scale) = self.aligned(other)
  normalize(left - right, scale)
}

///|
pub fn Number::multiply(self : Number, other : Number) -> Number {
  normalize(self.coefficient * other.coefficient, self.scale + other.scale)
}

///|
/// Return the additive inverse of this exact decimal.
pub fn Number::negate(self : Number) -> Number {
  normalize(-self.coefficient, self.scale)
}

///|
fn zeros(count : Int32) -> String {
  let mut result = ""
  for _ in 0..<count {
    result += "0"
  }
  result
}

///|
pub fn Number::to_canonical_string(self : Number) -> String {
  let signed = self.coefficient.to_string()
  if self.scale == 0 {
    return signed
  }
  let negative = signed.length() > 0 && signed[0] == '-'
  let digits = if negative { signed[1:].to_owned() } else { signed }
  let body = if digits.length() > self.scale {
    let split = digits.length() - self.scale
    digits[:split].to_owned() + "." + digits[split:].to_owned()
  } else {
    "0." + zeros(self.scale - digits.length()) + digits
  }
  if negative {
    "-" + body
  } else {
    body
  }
}

///|
fn Number::approximate_double(self : Number) -> Double {
  let parsed = @json.parse(
    self.to_canonical_string(),
    preserve_number_repr=true,
  ) catch {
    _ => return 0.0
  }
  match parsed {
    @builtin.Json::Number(value, ..) => value
    _ => 0.0
  }
}
