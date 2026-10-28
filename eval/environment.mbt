///|
priv struct Environment {
  bindings : Map[String, @value.Value]
  package_name : String?
  imports : Array[@syntax.Import]
}

///|
fn Environment::empty() -> Environment {
  { bindings: Map([]), package_name: None, imports: [], }
}

///|
fn Environment::for_package(package_name : String) -> Environment {
  { bindings: Map([]), package_name: Some(package_name), imports: [], }
}

///|
fn Environment::for_module(policy_module : @syntax.PolicyModule) -> Environment {
  {
    bindings: Map([]),
    package_name: Some(policy_module.package_name()),
    imports: policy_module.imports(),
  }
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
      Some({ bindings, package_name: self.package_name, imports: self.imports, })
    }
  }
}

///|
fn Environment::bind_local(
  self : Environment,
  name : String,
  value : @value.Value,
) -> Environment {
  let bindings = self.bindings.copy()
  bindings[name] = value
  { bindings, package_name: self.package_name, imports: self.imports, }
}
