package config

default valid := false

valid if {
  input.replicas >= 2
  input.image != ""
  input.public == false
}

test_default_rejects_missing_config if data.config.valid == false
