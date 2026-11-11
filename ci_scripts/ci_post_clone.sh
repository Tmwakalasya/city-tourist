#!/bin/bash
set -euo pipefail

# Resolve repository root whether called by Xcode Cloud ($CI_PRIMARY_REPOSITORY_PATH) or GitHub Actions.
REPO_ROOT="${CI_PRIMARY_REPOSITORY_PATH:-$(cd "$(dirname "$0")/.." && pwd)}"
RESOURCES_DIR="$REPO_ROOT/CityTourist/Resources"
EXAMPLE_PLIST="$RESOURCES_DIR/Secrets.example.plist"
SECRETS_PLIST="$RESOURCES_DIR/Secrets.plist"

if [ ! -f "$SECRETS_PLIST" ]; then
    cp "$EXAMPLE_PLIST" "$SECRETS_PLIST"
    echo "Created Secrets.plist from Secrets.example.plist"
fi

# Inject any environment variables configured in Xcode Cloud or GitHub Actions Secrets
# without printing secret values to logs.
set +x
inject_key() {
    local plist_key="$1"
    local env_var="$2"
    local val="${!env_var:-}"
    if [ -n "$val" ]; then
        plutil -replace "$plist_key" -string "$val" "$SECRETS_PLIST"
        echo "Injected $plist_key into Secrets.plist"
    fi
}

inject_key "GooglePlacesAPIKey"     "GOOGLE_PLACES_API_KEY"
inject_key "AIProxyURL"             "AI_PROXY_URL"
inject_key "TicketmasterAPIKey"     "TICKETMASTER_API_KEY"
inject_key "YouTubeAPIKey"          "YOUTUBE_API_KEY"
inject_key "FeedbackEmail"          "FEEDBACK_EMAIL"
inject_key "ShareBaseURL"           "SHARE_BASE_URL"
inject_key "SupabaseURL"            "SUPABASE_URL"
inject_key "SupabasePublishableKey" "SUPABASE_PUBLISHABLE_KEY"
inject_key "EventbriteProxyURL"     "EVENTBRITE_PROXY_URL"

# Verify Secrets.plist is valid XML/binary property list.
plutil -lint "$SECRETS_PLIST"

# In Xcode Cloud, automatically advance CURRENT_PROJECT_VERSION if CI_BUILD_NUMBER is set.
if [ -n "${CI_BUILD_NUMBER:-}" ]; then
    PBXPROJ="$REPO_ROOT/CityTourist.xcodeproj/project.pbxproj"
    if [ -f "$PBXPROJ" ]; then
        sed -i '' "s/CURRENT_PROJECT_VERSION = [0-9]*;/CURRENT_PROJECT_VERSION = ${CI_BUILD_NUMBER};/g" "$PBXPROJ"
        echo "Set CURRENT_PROJECT_VERSION to Xcode Cloud build number ${CI_BUILD_NUMBER}"
    fi
fi
