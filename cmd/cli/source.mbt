///|
pub struct PolicyBundle {
  program : @compile.Program
  modules : Array[@syntax.PolicyModule]
}

///|
pub fn PolicyBundle::program(self : PolicyBundle) -> @compile.Program {
  self.program
}

///|
pub fn PolicyBundle::modules(
  self : PolicyBundle,
) -> Array[@syntax.PolicyModule] {
  self.modules.copy()
}

///|
pub enum LoadPoliciesError {
  Io(String)
  Diagnostics(Array[@diagnostic.Diagnostic])
}

///|
pub enum InputError {
  Io(String)
  Json(String)
}

///|
pub async fn load_policy_bundle(
  paths : Array[String],
) -> Result[PolicyBundle, LoadPoliciesError] {
  let policy_paths = match collect_policy_paths(paths) {
    Ok(paths) => paths
    Err(message) => return Err(Io(message))
  }
  let modules : Array[@syntax.PolicyModule] = []
  let diagnostics : Array[@diagnostic.Diagnostic] = []
  for path in policy_paths {
    let source = match read_text(path) {
      Ok(text) => text
      Err(message) => return Err(Io("\{path}: \{message}"))
    }
    let parsed = @parser.parse_module(source, path)
    for diagnostic in parsed.diagnostics() {
      diagnostics.push(diagnostic)
    }
    match parsed.policy() {
      Some(policy) => modules.push(policy)
      None => ()
    }
  }
  if diagnostics.length() > 0 {
    return Err(Diagnostics(diagnostics))
  }
  let checked = @compile.compile_modules(modules)
  match checked.program() {
    Some(program) => Ok({ program, modules, })
    None => Err(Diagnostics(checked.diagnostics()))
  }
}

///|
async fn collect_policy_paths(
  paths : Array[String],
) -> Result[Array[String], String] {
  let found : Array[String] = []
  for path in paths {
    match walk_policy_path(path, true, found) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
  }
  if found.length() == 0 {
    return Err("no .rego policy files found in the provided paths")
  }
  sort_strings(found)
  Ok(found)
}

///|
async fn walk_policy_path(
  path : String,
  is_root : Bool,
  found : Array[String],
) -> Result[Unit, String] {
  let kind = @fs.kind(path, follow_symlink=false) catch {
    error => return Err("\{path}: \{error.to_string()}")
  }
  match kind {
    @fs.FileKind::Directory => {
      let directory = @fs.opendir(path) catch {
        error => return Err("\{path}: \{error.to_string()}")
      }
      defer directory.close()
      while directory.next(include_hidden=false) is Some(entry) {
        let child = join_path(path, entry.name)
        match walk_policy_path(child, false, found) {
          Ok(_) => ()
          Err(message) => return Err(message)
        }
      }
      Ok(())
    }
    @fs.FileKind::Regular =>
      if path.has_suffix(".rego") {
        found.push(path)
        Ok(())
      } else if is_root {
        Err("policy path must be a .rego file or a directory: \{path}")
      } else {
        Ok(())
      }
    @fs.FileKind::SymLink if is_root && path.has_suffix(".rego") => {
      found.push(path)
      Ok(())
    }
    @fs.FileKind::SymLink => Ok(())
    _ if is_root =>
      Err("policy path is not a regular file or directory: \{path}")
    _ => Ok(())
  }
}

///|
fn join_path(directory : String, name : String) -> String {
  if directory.has_suffix("/") || directory.has_suffix("\\") {
    "\{directory}\{name}"
  } else {
    "\{directory}/\{name}"
  }
}

///|
fn sort_strings(items : Array[String]) -> Unit {
  for i in 1..<items.length() {
    let mut j = i
    while j > 0 && items[j].compare(items[j - 1]) < 0 {
      let previous = items[j - 1]
      items[j - 1] = items[j]
      items[j] = previous
      j -= 1
    }
  }
}

///|
pub async fn read_text(path : String) -> Result[String, String] {
  let data = @fs.read_file(path) catch {
    error => return Err(error.to_string())
  }
  let text = data.text() catch { error => return Err(error.to_string()) }
  Ok(text)
}

///|
pub async fn read_json_value(
  path : String?,
) -> Result[@value.Value, InputError] {
  match path {
    None => Ok(@value.Value::null())
    Some(filename) => {
      let text = match read_text(filename) {
        Ok(text) => text
        Err(message) => return Err(Io("\{filename}: \{message}"))
      }
      let parsed = @json.parse(text, preserve_number_repr=true) catch {
        error => return Err(Json("\{filename}: \{error.to_string()}"))
      }
      match @value.Value::from_json(parsed) {
        Some(value) => Ok(value)
        None =>
          Err(Json("\{filename}: JSON number is outside supported syntax"))
      }
    }
  }
}
