#!/usr/bin/env bash

function check_package () {
    if ! hash "$1" 2> /dev/null; then
        echo "$1 is not installed"
        exit 1
    fi
}

check_package jq
check_package npm
check_package curl

DOWNLOAD_URL=$(curl -H "Accept-Encoding: identity" -H "Accept-Language: en" -s -L -A "Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1; BEDROCK-UPDATER)" https://minecraft.net/en-us/download/server/bedrock/ | grep -o 'https://[^"]*/bin-linux/[^"]*.zip')

if [ -z "$DOWNLOAD_URL" ]; then
    echo "Could not find the download URL."
    exit 1
fi

MCB_VERSION=$(echo "$DOWNLOAD_URL" | grep -oP 'bedrock-server-\K[0-9.]+(?=\.zip)')
# MCB_VERSION='1.21.62.01'
IFS='.' read -r -a MCB_VERSION_ARRAY <<< "$MCB_VERSION"

if [ -z "$MCB_VERSION_ARRAY" ]; then
    echo "Failed to extract version array from the download URL: $DOWNLOAD_URL"
    exit 1
fi

MCB_VERSION_MINOR=$(( (MCB_VERSION_ARRAY[2] / 10) * 10 ))
MCB_VERSION_ARRAY=(${MCB_VERSION_ARRAY[0]} ${MCB_VERSION_ARRAY[1]} ${MCB_VERSION_MINOR})
MCB_VERSION="${MCB_VERSION_ARRAY[0]}.${MCB_VERSION_ARRAY[1]}.${MCB_VERSION_ARRAY[2]}"

OLD_MCB_VERSION=$(jq -r '.header.min_engine_version | map(tostring) | join(".")' manifest.json)
if [ "$OLD_MCB_VERSION" == "$MCB_VERSION" ]; then
    echo "The new MCB Version and the actual are the same ($MCB_VERSION). Exiting..."
    exit 1
fi
echo -e "New MCB Version: ${MCB_VERSION}\n"

# Move to root path
cd "$(dirname "$0")/../.."

ADDON_VERSION_ARRAY=($(jq '.header.version[]' manifest.json))
ADDON_PREVIOUS_VERSION="${ADDON_VERSION_ARRAY[0]}.${ADDON_VERSION_ARRAY[1]}.${ADDON_VERSION_ARRAY[2]}"
echo "Actual Addon Version: $ADDON_PREVIOUS_VERSION"
NEW_MINOR=$((${ADDON_VERSION_ARRAY[2]}+1))
ADDON_VERSION_ARRAY=(${ADDON_VERSION_ARRAY[0]} ${ADDON_VERSION_ARRAY[1]} ${NEW_MINOR})
ADDON_VERSION="${ADDON_VERSION_ARRAY[0]}.${ADDON_VERSION_ARRAY[1]}.${ADDON_VERSION_ARRAY[2]}"
echo -e "New Addon Version: ${ADDON_VERSION}\n"

jq -r '.dependencies[] | "\(.module_name) \(.version)"' manifest.json | \
    while read -r module_name version; do

        npm_version=$(
            npm view "${module_name}@*" versions | \
            grep "beta.${MCB_VERSION_ARRAY[0]}.${MCB_VERSION_ARRAY[1]}.${MCB_VERSION_ARRAY[2]}" | \
            tail -n 1 | xargs | sed 's/,$//'
        )

        if [ -z "$npm_version" ]; then
            echo "Failed to get npm version for: $module_name"
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

sed -i "/## \[Unreleased\]/a \\
\\n## [$ADDON_VERSION] - $DATE\\n\\n### Changed\\n\\n- Upgrade dependencies (Compatible with $MCB_VERSION)\\n" "$CHANGELOG_FILE"

UNRELEASED_LINK_PATTERN="^\[unreleased\]: .*"
NEW_UNRELEASED_LINK="[unreleased]: ${GIT_URL}v${ADDON_VERSION}...HEAD\\n[${ADDON_VERSION}]: ${GIT_URL}v${ADDON_PREVIOUS_VERSION}...v${ADDON_VERSION}"

sed -i "s|$UNRELEASED_LINK_PATTERN|$NEW_UNRELEASED_LINK|" "$CHANGELOG_FILE"

echo "Updated Changelog to $ADDON_VERSION"