package authz

default allow := false

allowed_roles := {"admin", "operator"}

allow if {
  some role in input.roles
  role in data.authz.allowed_roles
  input.action == "read"
}

test_default_denies if data.authz.allow == false

test_admin_role_is_configured if "admin" in data.authz.allowed_roles
