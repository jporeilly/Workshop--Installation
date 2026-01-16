# Pentaho secrets policy
# Allows read access to database credentials

path "secret/data/pentaho/*" {
  capabilities = ["read", "list"]
}

path "secret/metadata/pentaho/*" {
  capabilities = ["list"]
}
