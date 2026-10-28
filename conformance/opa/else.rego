package else_oracle

decision := "primary" if { input.role == "admin" }
else := "secondary" if { input.role != "none" }
else := "fallback"

false_stops := false if { true }
else := true if { true }
