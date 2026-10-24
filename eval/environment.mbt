///|
priv struct Environment {
  bindings : Map[String, @value.Value]
}

///|
fn Environment::empty() -> Environment {
  { bindings: Map([]), }
}

///|
fn Environment::get(self : Environment, name : String) -> @value.Value? {
  self.bindings.get(name)
}

///|
fn Environment::bind(
  self : Environment,
  name : String,
  value : @value.Value,
) -> Environment? {
  match self.bindings.get(name) {
    Some(previous) => if previous.equal(value) { Some(self) } else { None }
    None => {
      let bindings : Map[String, @value.Value] = Map([])
      for (key, previous) in self.bindings {
        bindings[key] = previous
      }
      bindings[name] = value
      Some({ bindings, })
    }
  }
}
