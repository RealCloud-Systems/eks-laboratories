# Cluster roll: changing the root volume with should_roll replaces nodes in batches of 50%.
ocean = {
  should_roll           = true
  root_volume_size      = 40
  batch_size_percentage = 50
}
