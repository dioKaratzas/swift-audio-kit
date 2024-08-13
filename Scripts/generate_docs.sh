#!/bin/zsh

# Set the environment variable
export DOCC_JSON_PRETTYPRINT="YES"

# Move to the directory one level up from the script's location
cd "$(dirname "$0")"/..
echo "📂 Moved to project root: $(pwd)"

# Function to ensure the swift-docc-plugin is available
ensure_plugin_available() {
    local manifest_names=("Package@swift-5.9.swift" "Package@swift-5.8.swift" "Package@swift-5.7.swift" "Package@swift-5.10.swift" "Package@swift-6.0.swift" "Package.swift")
    local docc_plugin_dependency='.package(url: "https://github.com/apple/swift-docc-plugin.git", from: "1.3.0"),'
    local insertion_marker='Package dependencies'

    for manifest_name in "${manifest_names[@]}"; do
        if [ -f "$manifest_name" ]; then
            local manifest_contents
            manifest_contents=$(cat "$manifest_name")

            if [[ "$manifest_contents" == *"$insertion_marker"* ]]; then
                if [[ "$manifest_contents" != *"$docc_plugin_dependency"* ]]; then
                    echo "🧬  Injecting missing DocC plugin dependency in $manifest_name"
                    
                    # Insert the dependency in the dependencies section using the marker
                    sed -i '' "/$insertion_marker/a\\
        $docc_plugin_dependency
                    " "$manifest_name"
                else
                    echo "✅  DocC plugin dependency already present in $manifest_name"
                fi
                return
            fi
        fi
    done

    echo "❌  ERROR: Can't inject swift-docc-plugin dependency (no usable manifest found with a dependencies array)."
    exit 1
}

# Ensure the swift-docc-plugin is available in the manifest
ensure_plugin_available

# Remove the docs folder if it exists
if [ -d "./docs" ]; then
    echo "🗑️  Removing existing docs folder..."
    rm -rf ./docs
else
    echo "📂 No existing docs folder found, proceeding..."
fi

# Remove the .build folder if it exists
if [ -d "./.build" ]; then
    echo "🗑️  Removing .build folder..."
    rm -rf ./.build
else
    echo "📂 No .build folder found, proceeding..."
fi

# Delete the local gh-pages branch if it exists
if git show-ref --quiet refs/heads/gh-pages; then
    echo "🗑️  Deleting existing local gh-pages branch..."
    git branch -D gh-pages
else
    echo "📂 No local gh-pages branch found, proceeding..."
fi

# Fetch the latest updates from the remote repository
echo "🔄 Fetching the latest changes from the remote repository..."
git fetch origin

# Checkout the latest master branch as gh-pages
echo "🌿 Checking out the latest master branch as gh-pages..."
git checkout -b gh-pages origin/master || git checkout -b gh-pages master

# Generate Documentation
echo "📖 Generating documentation for SwiftAudioKit..."
swift package \
    --allow-writing-to-directory ./docs \
    generate-documentation --target SwiftAudioKit \
    --disable-indexing \
    --transform-for-static-hosting \
    --hosting-base-path swift-audio-kit \
    --output-path ./docs

# Check if the documentation generation was successful
if [ $? -ne 0 ]; then
    echo "❌ Documentation generation failed. Exiting..."
    exit 1
fi

echo "✅ Documentation successfully generated."

# Commit the generated documentation
echo "📝 Committing the generated documentation..."
git add docs
git commit -m "Update documentation for SwiftAudioKit"

# Push the gh-pages branch to the remote repository
echo "🚀 Pushing the gh-pages branch to the remote repository..."
git push -f -u origin gh-pages

# Check if the push was successful
if [ $? -eq 0 ]; then
    echo "✅ Documentation successfully pushed to the gh-pages branch."
else
    echo "❌ Failed to push to the gh-pages branch. Exiting..."
    exit 1
fi

echo "🎉 Script completed successfully."
