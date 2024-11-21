#!/bin/sh

# outputs a pkg invocation that installs a package directly from FreeBSD without modifying repos
# credit: https://medium.com/@mihakralj/the-direct-route-installing-freebsd-packages-on-opnsense-d002ac0c56b8

get_freebsd_catalog() {
  # Determine FreeBSD version, stitch together FreeBSD repourl
  freebsd_version=$(freebsd-version -u | cut -d- -f1 | cut -d. -f1)
  repourl="https://pkg.freebsd.org/FreeBSD:${freebsd_version}:$(uname -m)/latest"

  # Create a temporary directory if it doesn't exist
  tmp_dir="/tmp/pkg_site_tmp_dir" && mkdir -p "$tmp_dir"

  # Fetch and unpack the packagesite file
  fetch -q -o "${tmp_dir}/packagesite.txz" "${repourl}/packagesite.txz"
  tar -xf "${tmp_dir}/packagesite.txz" -C "$tmp_dir" packagesite.yaml
  rm "${tmp_dir}/packagesite.txz" # Delete the tar file after extracting
}

grep_package_in_catalog() {
  matching_packages=$(pkg search "$1" | grep "^$1-")
  [ -n "$matching_packages" ] && return 0
  package_info=$(grep "\"name\":\"$1\"" "${tmp_dir}/packagesite.yaml")
  [ -z "$package_info" ] && echo "pkg $1 not found" && return 1
  # echo "$package_info" | jq .
  package_url="${repourl}/$(echo "$package_info" | sed -n 's/.*"repopath":"\([^"]*\)".*/\1/p')"
  echo "pkg add $package_url"
}

# The main() part of the script starts here
[ $# -eq 0 ] && { echo "Usage: $0 <package_name>"; exit 1; }
get_freebsd_catalog
grep_package_in_catalog "$1"
