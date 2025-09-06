#!/usr/bin/env bash
set -euo pipefail

## START flags
force=false
version=""

# Parse arguments
for arg in "$@"; do
  case "$arg" in
    --force)
      force=true
      ;;
    --version=*)
      version="${arg#*=}"
      ;;
    *)
      echo "::error ::Unknown option: $arg"
      exit 1
      ;;
  esac
done
## END flags

function check_package () {
    if ! hash "$1" 2> /dev/null; then
        echo "::error ::$1 is not installed"
        exit 1
    fi
}

check_package jq
check_package npm
check_package curl

DOWNLOAD_URL=$(curl -H "Accept-Encoding: identity" -H "Accept-Language: en" -s -L -A "Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1; BEDROCK-UPDATER)" https://net-secondary.web.minecraft-services.net/api/v1.0/download/links | grep -o 'https://[^"]*/bin-linux/[^"]*.zip')

if [ -z "$DOWNLOAD_URL" ]; then
    echo "::error ::Could not find the download URL."
    {
      echo "## ❌ Download Failed"
      echo ""
      echo "Reason: Could not find a valid Bedrock server download URL."
      echo ""
      echo "Endpoint checked: https://net-secondary.web.minecraft-services.net/api/v1.0/download/links"
    } >> "$GITHUB_STEP_SUMMARY"
    exit 1
fi

MCB_VERSION=$(echo "$DOWNLOAD_URL" | grep -oP 'bedrock-server-\K[0-9.]+(?=\.zip)')
IFS='.' read -r -a MCB_VERSION_ARRAY <<< "$MCB_VERSION"

if [ -z "$MCB_VERSION_ARRAY" ]; then
    echo "::error ::Failed to extract version array from the download URL: $DOWNLOAD_URL"
    {
      echo "## ❌ Version Parsing Failed"
      echo ""
      echo "Reason: Could not extract version array from the download URL."
      echo ""
      echo "URL: \`$DOWNLOAD_URL\`"
    } >> "$GITHUB_STEP_SUMMARY"
    exit 1
fi

MCB_VERSION_MINOR=$(( (MCB_VERSION_ARRAY[2] / 10) * 10 ))
MCB_VERSION_ARRAY=(${MCB_VERSION_ARRAY[0]} ${MCB_VERSION_ARRAY[1]} ${MCB_VERSION_MINOR})
MCB_VERSION="${MCB_VERSION_ARRAY[0]}.${MCB_VERSION_ARRAY[1]}.${MCB_VERSION_ARRAY[2]}"

OLD_MCB_VERSION=$(jq -r '.header.min_engine_version | map(tostring) | join(".")' manifest.json)
if $force; then
  echo "Skipping comparison of MCB versions due to --force flag."
else
    if [ "$OLD_MCB_VERSION" == "$MCB_VERSION" ]; then
        echo "::warning ::The new MCB Version and the actual are the same ($MCB_VERSION). Nothing to do."
        echo "skipped=true" >> "$GITHUB_OUTPUT"

        {
          echo "## 🚫 Skipped Release"
          echo ""
          echo "**Reason:** The new MCB Version \`$MCB_VERSION\` is the same as the current version."
          echo ""
          echo "No changes were made and no release will be created."
        } >> "$GITHUB_STEP_SUMMARY"

        exit 0
    fi
fi

echo -e "MCB Version: ${MCB_VERSION}\n"

ADDON_VERSION_ARRAY=($(jq '.header.version[]' manifest.json))
ADDON_PREVIOUS_VERSION="${ADDON_VERSION_ARRAY[0]}.${ADDON_VERSION_ARRAY[1]}.${ADDON_VERSION_ARRAY[2]}"
echo "Actual Addon Version: $ADDON_PREVIOUS_VERSION"

if [[ -z "$version" ]]; then
    NEW_MINOR=$((${ADDON_VERSION_ARRAY[2]}+1))
    ADDON_VERSION_ARRAY=(${ADDON_VERSION_ARRAY[0]} ${ADDON_VERSION_ARRAY[1]} ${NEW_MINOR})
    ADDON_VERSION="${ADDON_VERSION_ARRAY[0]}.${ADDON_VERSION_ARRAY[1]}.${ADDON_VERSION_ARRAY[2]}"
else
    echo "Version to update: $version"
    if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "::error ::Invalid version format. Use x.x.x"
        exit 1
    fi

    if [[ "$(printf '%s\n' "$ADDON_PREVIOUS_VERSION" "$version" | sort -V | head -n1)" != "$ADDON_PREVIOUS_VERSION" ]]; then
        echo "::error ::Version $version is lower than the current version $ADDON_PREVIOUS_VERSION."
        exit 1
    fi

    IFS='.' read -r -a ADDON_VERSION_ARRAY <<< "$version"
    ADDON_VERSION="${ADDON_VERSION_ARRAY[0]}.${ADDON_VERSION_ARRAY[1]}.${ADDON_VERSION_ARRAY[2]}"
fi

echo -e "New Addon Version: ${ADDON_VERSION}\n"

jq -r '.dependencies[] | "\(.module_name) \(.version)"' manifest.json | \
    while read -r module_name version; do

        npm_version=$(
            npm view "${module_name}@*" versions | \
            grep "beta.${MCB_VERSION_ARRAY[0]}.${MCB_VERSION_ARRAY[1]}.${MCB_VERSION_ARRAY[2]}-stable" | \
            tail -n 1 | xargs | sed 's/,$//'
        )

        if [ -z "$npm_version" ]; then
            echo "::error ::Failed to get npm version for: $module_name"
            {
              echo "## ❌ Dependency Update Failed"
              echo ""
              echo "**Module:** \`$module_name\`"
              echo ""
              echo "Reason: Could not find a matching npm version for **MCB $MCB_VERSION**."
            } >> "$GITHUB_STEP_SUMMARY"
            exit 1
        fi

        module_version=$(
            echo "$npm_version" | grep -o '^[0-9.]\+-beta'
        )

        echo "$module_name - LAST NPM VERSION: $npm_version - LAST MODULE VERSION: $module_version"

        jq --arg dep "${module_name}" --arg ver "${npm_version}" '.dependencies[$dep] = $ver' package.json > package.temp.json && \
            mv package.temp.json package.json

        jq --arg module "${module_name}" --arg version "${module_version}" '(.dependencies[] | select(.module_name == $module) .version) = $version' manifest.json > manifest.temp && \
            mv manifest.temp manifest.json

    done

jq --arg version "$ADDON_VERSION" '.version = $version' package.json > package.temp.json && \
    mv package.temp.json package.json

jq ".header.version = [${ADDON_VERSION_ARRAY[0]}, ${ADDON_VERSION_ARRAY[1]}, ${ADDON_VERSION_ARRAY[2]}] |
    .modules[0].version = [${ADDON_VERSION_ARRAY[0]}, ${ADDON_VERSION_ARRAY[1]}, ${ADDON_VERSION_ARRAY[2]}] |
    .header.min_engine_version = [${MCB_VERSION_ARRAY[0]}, ${MCB_VERSION_ARRAY[1]}, ${MCB_VERSION_ARRAY[2]}]" manifest.json > manifest.temp.json && \
    mv manifest.temp.json manifest.json

GIT_URL="https://github.com/jsilverdev/event-catcher-mcb-addon/compare/"
CHANGELOG_FILE="CHANGELOG.md"
DATE=$(date +"%Y-%m-%d")

temp_file="$(mktemp)"
comment="- Upgrade dependencies (Compatible with $MCB_VERSION)"

awk -v text="$comment" -v found_var="__CHANGED_FOUND__" '
  BEGIN { in_unreleased=0; changed_inserted=0 }
  /^## \[Unreleased\]/ {
    in_unreleased=1
    print
    next
  }
  in_unreleased && /^## \[/ {
    in_unreleased=0
  }
  in_unreleased && /^### Changed/ && !changed_inserted {
    print
    print ""
    print text
    changed_inserted=1
    next
  }
  { print }
  END {
    if (!changed_inserted) {
      print found_var
    }
  }
' "$CHANGELOG_FILE" > "$temp_file"

if grep -q "__CHANGED_FOUND__" "$temp_file"; then
    sed -i "/## \[Unreleased\]/a \\
\\n## [$ADDON_VERSION] - $DATE\\n\\n### Changed\\n\\n$comment\\n" "$temp_file"
else
    sed -i "/## \[Unreleased\]/a \\
\\n## [$ADDON_VERSION] - $DATE\\n" "$temp_file"
fi

sed -i '/__CHANGED_FOUND__/d' "$temp_file"

mv "$temp_file" "$CHANGELOG_FILE"

UNRELEASED_LINK_PATTERN="^\[unreleased\]: .*"
NEW_UNRELEASED_LINK="[unreleased]: ${GIT_URL}v${ADDON_VERSION}...HEAD\\n[${ADDON_VERSION}]: ${GIT_URL}v${ADDON_PREVIOUS_VERSION}...v${ADDON_VERSION}"

sed -i "s|$UNRELEASED_LINK_PATTERN|$NEW_UNRELEASED_LINK|" "$CHANGELOG_FILE"

echo "::notice ::Updated Changelog to $ADDON_VERSION"