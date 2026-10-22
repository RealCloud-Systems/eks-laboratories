# Spot interruption: keep 2 Spot nodes up so there is something to interrupt with AWS FIS.
vngs = {
  general = {
    min_instance_count = 2
  }
}

# Creates the FIS role and the experiment template that interrupts one Ocean node
fis = {
  enabled = true
}
