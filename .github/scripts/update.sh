#!/usr/bin/env bash

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

# Move to root path
cd "$(dirname "$0")/../.."

ADDON_VERSION_ARRAY=($(jq '.header.version[]' manifest.json))
echo "Actual Addon Version: ${ADDON_VERSION_ARRAY[0]}.${ADDON_VERSION_ARRAY[1]}.${ADDON_VERSION_ARRAY[2]}"
NEW_MINOR=$((${ADDON_VERSION_ARRAY[2]}+1))
ADDON_VERSION_ARRAY=(${ADDON_VERSION_ARRAY[0]} ${ADDON_VERSION_ARRAY[1]} ${NEW_MINOR})
echo "New Addon Version: ${ADDON_VERSION_ARRAY[0]}.${ADDON_VERSION_ARRAY[1]}.${ADDON_VERSION_ARRAY[2]}"

jq -r '.dependencies[] | "\(.module_name) \(.version)"' manifest.json | \
    while read -r module_name version; do

        npm_version=$(npm view "${module_name}@*" versions | \
            grep "beta.${MCB_VERSION_ARRAY[0]}.${MCB_VERSION_ARRAY[1]}.${MCB_VERSION_ARRAY[2]}" | \
            tail -n 1 | xargs | sed 's/,$//')

        echo "$module_name last npm version: $npm_version"

        jq --arg dep "${module_name}" --arg ver "${npm_version}" '.dependencies[$dep] = $ver' package.json > package.temp.json && \
            mv package.temp.json package.json

        jq --arg module "${module_name}" --arg version "${npm_version}" '.dependencies[] | (select(.module_name == $module)).version = $version' manifest.json > manifest.temp && \
            mv manifest.temp manifest.json

    done

jq ".header.version = [${ADDON_VERSION_ARRAY[0]}, ${ADDON_VERSION_ARRAY[1]}, ${ADDON_VERSION_ARRAY[2]}] |
    .modules[0].version = [${ADDON_VERSION_ARRAY[0]}, ${ADDON_VERSION_ARRAY[1]}, ${ADDON_VERSION_ARRAY[2]}] |
    .header.min_engine_version = [${MCB_VERSION_ARRAY[0]}, ${MCB_VERSION_ARRAY[1]}, ${MCB_VERSION_ARRAY[2]}]" manifest.json > manifest.temp.json && \
    mv manifest.temp.json manifest.json