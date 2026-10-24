///|
pub(all) enum OutputFormat {
  Pretty
  Json
} derive(Eq)

///|
pub extend OutputFormat with Eq::{equal, not_equal}

///|
pub(all) enum CliCommand {
  Help
  Check(Array[String], OutputFormat)
  Eval(String, String?, String?, Array[String], Bool, OutputFormat)
  Test(Array[String], OutputFormat)
}

///|
pub fn parse_args(args : Array[String]) -> Result[CliCommand, String] {
  if args.length() == 0 ||
    args[0] == "help" ||
    args[0] == "--help" ||
    args[0] == "-h" {
    return Ok(Help)
  }
  match args[0] {
    "check" => parse_policy_command(args, false)
    "test" => parse_policy_command(args, true)
    "eval" => parse_eval_args(args)
    _ => Err("expected one of: check, eval, test, help")
  }
}

///|
fn parse_policy_command(
  args : Array[String],
  is_test : Bool,
) -> Result[CliCommand, String] {
  let policies : Array[String] = []
  let mut format = Pretty
  let mut index = 1
  while index < args.length() {
    let argument = args[index]
    if argument == "--format" {
      if index + 1 >= args.length() {
        return Err("--format requires pretty or json")
      }
      format = match args[index + 1] {
        "pretty" => Pretty
        "json" => Json
        _ => return Err("--format requires pretty or json")
      }
      index += 2
    } else if argument.has_prefix("-") {
      return Err("unexpected option '{argument}'")
    } else {
      policies.push(argument)
      index += 1
    }
  }
  if policies.length() == 0 {
    return Err("at least one policy file is required")
  }
  if is_test {
    Ok(Test(policies, format))
  } else {
    Ok(Check(policies, format))
  }
}

///|
fn parse_eval_args(args : Array[String]) -> Result[CliCommand, String] {
  if args.length() < 2 || args[1].has_prefix("-") {
    return Err("eval requires a query expression")
  }
  let query = args[1]
  let mut input : String? = None
  let mut data : String? = None
  let policies : Array[String] = []
  let mut strict = false
  let mut format = Pretty
  let mut index = 2
  while index < args.length() {
    let argument = args[index]
    if argument == "-i" || argument == "--input" {
      if index + 1 >= args.length() || input is Some(_) {
        return Err("--input must appear once and requires a file path")
      }
      input = Some(args[index + 1])
      index += 2
    } else if argument == "-d" || argument == "--data" {
      if index + 1 >= args.length() || data is Some(_) {
        return Err("--data must appear once and requires a file path")
      }
      data = Some(args[index + 1])
      index += 2
    } else if argument == "--strict-builtin-errors" {
      strict = true
      index += 1
    } else if argument == "--format" {
      if index + 1 >= args.length() {
        return Err("--format requires pretty or json")
      }
      format = match args[index + 1] {
        "pretty" => Pretty
        "json" => Json
        _ => return Err("--format requires pretty or json")
      }
      index += 2
    } else if argument.has_prefix("-") {
      return Err("unexpected option '{argument}'")
    } else {
      policies.push(argument)
      index += 1
    }
  }
  if policies.length() == 0 {
    return Err("eval requires at least one policy file")
  }
  Ok(Eval(query, input, data, policies, strict, format))
}
