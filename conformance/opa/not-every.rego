package every_negative

allow if {
  not every role in input.roles {
    true
  }
}
