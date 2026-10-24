package access

default allow := false

allow if {
  every role in input.roles {
    role != "blocked"
  }
  every name, principal in input.principals {
    startswith(name, "team-")
    "staff" in principal.roles
  }
}
