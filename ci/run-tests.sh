#!/bin/bash
set -e

VERSION="${TRAVIS_TAG:-0.0.0}"
VERSION="${VERSION#v}"

readonly ROOT_DIR="$(dirname "$(dirname "${0}")")"
cd "${ROOT_DIR}"

function test_fluentd_plugin() {
  local plugin_name="${1}"
  local version="${2}"
  # Strip everything after "-" (longest match) to avoid gem prerelease behavior
  local gem_version="${version%%-*}"

  cd "${plugin_name}" || exit 1

  if [[ "${version}" == "" ]] ; then
    echo "Please provide the version when bundling fluentd plugins"
    exit 1
  fi

  echo "Preparing gem ${plugin_name} version ${gem_version} in $(pwd) for testing ..."
  sed -i.bak "s/0.0.0/${gem_version}/g" ./"${plugin_name}".gemspec
  rm -f ./"${plugin_name}".gemspec.bak

  echo "Install bundler..."
  bundle install

  echo "Run unit tests..."
  bundle exec rake || exit 1
}

function test_fluentd_plugins() {
  local version="${1}"

  if [[ "${version}" == "" ]] ; then
    echo "Please provide the version when bundling fluentd plugins"
    exit 1
  fi

  find . -name 'fluent-plugin-*' -type 'd' -print |
    while read -r line; do
      # Run tests in their own context
      (test_fluentd_plugin "$(basename "${line}")" "${version}") || exit 1
    done
}

## check the build scripts with shellcheck
echo "Checking the build script with shellcheck..."
shellcheck ci/build.sh
shellcheck ci/run-tests.sh

# Test if template files are generated correctly for various values.yaml
echo "Test helm templates generation"
./tests/run.sh || (echo "Failed testing templates" && exit 1)

# Test upgrade script
echo "Test upgrade script..."
./tests/upgrade_script/run.sh || (echo "Failed testing upgrade script" && exit 1)

# Test fluentd plugins
test_fluentd_plugins "${VERSION}" || (echo "Failed testing fluentd plugins" && exit 1)

echo "DONE"
