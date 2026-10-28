package every_oracle

array_every if {
  every index, role in input.roles {
    index >= 0
    role != "blocked"
  }
}

object_every if {
  every name, user in input.users {
    startswith(name, "team-")
    "staff" in user.roles
  }
}

set_every if {
  every tag in {"web", "api"} {
    tag != "blocked"
  }
}

blocked_set_every if {
  every tag in {"web", "blocked"} {
    tag != "blocked"
  }
}

object_value_every if {
  every user in input.users {
    "staff" in user.roles
  }
}

empty_every if {
  every item in [] {
    item > 0
  }
}

empty_object_every if {
  every item in {} {
    item > 0
  }
}

empty_set_every if {
  every item in set() {
    item > 0
  }
}

undefined_every if {
  every item in input.missing {
    item > 0
  }
}

outer_binding if {
  role := "outside"
  every role in ["inside"] {
    role == "inside"
  }
  role == "outside"
}
