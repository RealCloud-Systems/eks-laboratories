# Blue/green roll: a new app version, rolled to every instance in batches of 50%.
app = {
  version = "v2"
}

elastigroup = {
  roll = {
    batch_size_percentage = 50
    grace_period          = 180
    health_check_type     = "TARGET_GROUP"
  }
}
