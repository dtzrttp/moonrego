package every_duplicate_binder

equal_pair if {
  every item, item in input.equal {
    item == "same"
  }
}

unequal_pair if {
  every item, item in input.unequal {
    item == "value"
  }
}
