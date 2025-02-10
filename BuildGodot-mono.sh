#!/bin/bash
# Copyright (c) 2025 Martin Majewski
# Email: mail@martinmajewski.net
# Website: https://www.martinmajewski.net

GODOT_NAME="Godot-Mono"
DOUBLE_PRECISION=true

echo "#######################"
echo "Building $GODOT_NAME for MacOS arm64 with .Net and Vulkan support..."

# Function to check the last command status and exit if it failed
check_error() {
    if [ $? -ne 0 ]; then
        echo "Error: $1"
        exit 1
    fi
}

# Update and upgrade Homebrew
brew update
check_error "Failed to update Homebrew"
brew upgrade
check_error "Failed to upgrade Homebrew"

# Switch to the Godot directory if it exists
if [ -d "godot" ]; then
    cd godot
    check_error "Failed to change directory to godot"

    # Check if we are already inside the Godot repository's directory
    if [ -d ".git" ] && [ "$(git rev-parse --show-toplevel)" == "$(pwd)" ]; then
        echo "Already inside the Godot repository. Updating..."
    else
        echo "Godot repository exists. Updating..."
    fi

    # Pull the latest changes
    git pull origin master
    check_error "Failed to pull the latest changes from the Godot repository"
    echo "Godot repository updated to latest remote's master state."
# Clone the Godot repository if it does not exist yet
else
    echo "Godot repository does not exist. Cloning..."
    # Clone the Godot repository
    git clone https://github.com/godotengine/godot.git
    check_error "Failed to clone the Godot repository"

    # Print clone completion message
    echo "Godot repository cloned successfully."
    cd godot
    check_error "Failed to change directory to godot"
fi
echo "-----------------------"

# Build the Godot engine for MacOS arm64 with Vulkan support
if [ "$DOUBLE_PRECISION" = true ]; then
    scons platform=macos arch=arm64 volk=yes module_mono_enabled=yes precision=double
else
    scons platform=macos arch=arm64 volk=yes module_mono_enabled=yes
fi
check_error "Failed to build the Godot engine"

# Build export templates
scons platform=macos target=template_debug module_mono_enabled=yes
check_error "Failed to build template_debug"
scons platform=macos target=template_release module_mono_enabled=yes
check_error "Failed to build template_release"

# Print compile completion message
echo "$GODOT_NAME build for MacOS arm64 completed successfully."

# Generate Mono Glue
echo "-----------------------"
echo "Generating Mono Glue..."
if [ "$DOUBLE_PRECISION" = true ]; then
    bin/godot.macos.editor.double.arm64.mono --headless --generate-mono-glue modules/mono/glue
else
    bin/godot.macos.editor.arm64.mono --headless --generate-mono-glue modules/mono/glue
fi
check_error "Failed to generate Mono Glue"

# Build Managed Libraries
echo "-----------------------"
echo "Building Managed Libraries..."
if [ "$DOUBLE_PRECISION" = true ]; then
    ./modules/mono/build_scripts/build_assemblies.py --godot-output-dir=./bin --push-nupkgs-local ~/Developer/DotNet/local_nuget_source --precision=double
else

# Package the Godot engine for MacOS
echo "-----------------------"
echo "Packaging $GODOT_NAME for MacOS arm64..."
cp -r misc/dist/macos_tools.app ./$GODOT_NAME.app
check_error "Failed to copy macos_tools.app"
mkdir -p $GODOT_NAME.app/Contents/MacOS
cp -r bin/GodotSharp $GODOT_NAME.app/Contents/
check_error "Failed to copy GodotSharp"
if [ "$DOUBLE_PRECISION" = true ]; then
    cp bin/godot.macos.editor.double.arm64.mono $GODOT_NAME.app/Contents/MacOS/$GODOT_NAME
else
    cp bin/godot.macos.editor.arm64.mono $GODOT_NAME.app/Contents/MacOS/$GODOT_NAME
fi
check_error "Failed to copy Godot binary"
chmod +x $GODOT_NAME.app/Contents/MacOS/$GODOT_NAME

# Copy MoltenVK library to the Godot.app
echo "-----------------------"
molten_vk_path=$(brew --cellar molten-vk)/$(brew info --json molten-vk | jq -r '.[0].installed[0].version')
echo "Copying MoltenVK library to $GODOT_NAME.app - using $molten_vk_path"
mkdir -p $GODOT_NAME.app/Contents/Frameworks
sudo cp $molten_vk_path/lib/libMoltenVK.dylib $GODOT_NAME.app/Contents/Frameworks/libMoltenVK.dylib
check_error "Failed to copy MoltenVK library"

# Change permission to 755
echo "Current permission for libMoltenVK.dylib is: $(stat -f %A $GODOT_NAME.app/Contents/Frameworks/libMoltenVK.dylib)"
echo "Changing permission to 755 for libMoltenVK.dylib"
sudo chmod 755 $GODOT_NAME.app/Contents/Frameworks/libMoltenVK.dylib
check_error "Failed to change permission for libMoltenVK.dylib"

echo "Signing $GODOT_NAME.app..."
codesign --force --timestamp --options=runtime --entitlements misc/dist/macos/editor.entitlements -s - $GODOT_NAME.app
check_error "Failed to sign $GODOT_NAME.app"

# Print packaging completion message
echo "$GODOT_NAME packaged and signed successfully."

echo "Finished building $GODOT_NAME!"
echo "#######################"
