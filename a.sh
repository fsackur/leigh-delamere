#!/usr/bin/awk -f

BEGIN {
  search=ARGV[1];  # Grab the first command line option
  delete ARGV[1];  # Delete it so it won't be considered a file
}

# First, store every line in an array keyed on the Queue ID.
# Obviously, this only works for smallish log segments, as it uses up memory.
{
  line[$6]=sprintf("%s\n%s", line[$6], $0);
}

# Next, keep a record of Queue IDs with substrings that match our search string.
index($0, search) {
  show[$6];
}

# Finally, once we've processed all input data, walk through our array of "found"
# Queue IDs, and print the corresponding records from the storage array.
END {
  for(qid in show) {
    print line[qid];
  }
}
