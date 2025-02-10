#!/bin/bash
# Copyright (c) 2025 Martin Majewski
# Email: mail@martinmajewski.net
# Website: https://www.martinmajewski.net

# Variables
GODOT_APP_NAME="Godot-Mono"
DOUBLE_PRECISION=true

# Function to check the last command status and exit if it failed
check_error() {
    if [ $? -ne 0 ]; then
        echo "Error: $1"
        exit 1
    fi
}

# Check if the script is executed inside the Scripts folder
if [[ "$(basename $(pwd))" == "Scripts" ]]; then
    echo ""
    echo "WARNING: We are inside the Scripts folder! Changing directory to the parent folder..."
    cd ..
    check_error "Failed to change directory out of Scripts folder"
fi

echo ""
echo "#######################"
echo "Building $GODOT_APP_NAME for MacOS arm64 with .Net and Vulkan support..."

# echo ""
# # Update and upgrade Homebrew
# echo "-----------------------"
# brew update
# check_error "Failed to update Homebrew"
# brew upgrade
# check_error "Failed to upgrade Homebrew"

echo ""
# Switch to the Godot directory if it exists and is a Git repository
echo "-----------------------"
if [ -d "godot" ] && [ -d "godot/.git" ] && [[ "$(pwd)" != *"/godot"* ]]; then
    cd godot
    check_error "Failed to change directory to godot"

    echo "Already inside the Godot repository. Updating..."

    # Pull the latest changes
    git pull origin master
    check_error "Failed to pull the latest changes from the Godot repository"
    echo "Godot repository updated to latest remote's master state."

# Clone the Godot repository if it does not exist yet
else
    echo "Godot repository does not exist or we are in a subdirectory. Cloning..."
    # Clone the Godot repository
    git clone https://github.com/godotengine/godot.git
    check_error "Failed to clone the Godot repository"

    # Print clone completion message
    echo "Godot repository cloned successfully."
    cd godot
    check_error "Failed to change directory to godot"
fi

echo ""
# Install Vulkan SDK
echo "-----------------------"
echo "Installing Vulkan SDK..."
./misc/scripts/install_vulkan_sdk_macos.sh
check_error "Failed to install Vulkan SDK"

echo ""
# Build the Godot engine for MacOS arm64 with Vulkan support
echo "-----------------------"
if [ "$DOUBLE_PRECISION" = true ]; then
    scons platform=macos arch=arm64 volk=yes module_mono_enabled=yes precision=double
else
    scons platform=macos arch=arm64 volk=yes module_mono_enabled=yes
fi
check_error "Failed to build the Godot engine"

echo ""
# Build export templates
echo "-----------------------"
scons platform=macos target=template_debug module_mono_enabled=yes
check_error "Failed to build template_debug"
scons platform=macos target=template_release module_mono_enabled=yes
check_error "Failed to build template_release"

# Print compile completion message
echo "$GODOT_APP_NAME build for MacOS arm64 completed successfully."

echo ""
# Generate Mono Glue
echo "-----------------------"
echo "Generating Mono Glue..."
if [ "$DOUBLE_PRECISION" = true ]; then
    bin/godot.macos.editor.double.arm64.mono --headless --generate-mono-glue modules/mono/glue
else
    bin/godot.macos.editor.arm64.mono --headless --generate-mono-glue modules/mono/glue
fi
check_error "Failed to generate Mono Glue"

echo ""
# Build Managed Libraries
echo "-----------------------"
echo "Building Managed Libraries..."
if [ "$DOUBLE_PRECISION" = true ]; then
    ./modules/mono/build_scripts/build_assemblies.py --godot-output-dir=./bin --push-nupkgs-local ~/Developer/DotNet/local_nuget_source --precision=double
else
    ./modules/mono/build_scripts/build_assemblies.py --godot-output-dir=./bin --push-nupkgs-local ~/Developer/DotNet/local_nuget_source
fi

echo ""
# Package the Godot engine for MacOS
echo "-----------------------"
echo "Packaging $GODOT_APP_NAME for MacOS arm64..."

echo "Removing old $GODOT_APP_NAME.app..."
rm -rf $GODOT_APP_NAME.app
check_error "Failed to remove old $GODOT_APP_NAME.app"

echo "Copying macos_tools.app to $GODOT_APP_NAME.app..."
cp -r misc/dist/macos_tools.app ./$GODOT_APP_NAME.app
check_error "Failed to copy macos_tools.app"

echo "Creating Contents/MacOS directory..."
mkdir -p $GODOT_APP_NAME.app/Contents/MacOS
check_error "Failed to create Contents/MacOS directory"

echo "Copying GodotSharp to $GODOT_APP_NAME.app/Contents/Resources/..."
cp -rp bin/GodotSharp $GODOT_APP_NAME.app/Contents/Resources/
check_error "Failed to copy GodotSharp"

echo "Copying GodotSharpAssemblies to $GODOT_APP_NAME.app/Contents/MacOS/..."
if [ "$DOUBLE_PRECISION" = true ]; then
    cp bin/godot.macos.editor.double.arm64.mono $GODOT_APP_NAME.app/Contents/MacOS/Godot
else
    cp bin/godot.macos.editor.arm64.mono $GODOT_APP_NAME.app/Contents/MacOS/Godot
fi
check_error "Failed to copy GodotSharpAssemblies"

echo "Changing permission to 755 for $GODOT_APP_NAME..."
chmod +x $GODOT_APP_NAME.app/Contents/MacOS/Godot

# echo ""
# # Copy MoltenVK library to the Godot.app
# echo "-----------------------"
# molten_vk_path=$(brew --cellar molten-vk)/$(brew info --json molten-vk | jq -r '.[0].installed[0].version')
# echo "Copying MoltenVK library to $GODOT_APP_NAME.app - using $molten_vk_path"
# mkdir -p $GODOT_APP_NAME.app/Contents/Frameworks
# sudo cp $molten_vk_path/lib/libMoltenVK.dylib $GODOT_APP_NAME.app/Contents/Frameworks/libMoltenVK.dylib
# check_error "Failed to copy MoltenVK library"

# echo ""
# # Change permission to 755
# echo "-----------------------"
# echo "Current permission for libMoltenVK.dylib is: $(stat -f %A $GODOT_APP_NAME.app/Contents/Frameworks/libMoltenVK.dylib)"
# echo "Changing permission to 755 for libMoltenVK.dylib"
# sudo chmod 755 $GODOT_APP_NAME.app/Contents/Frameworks/libMoltenVK.dylib
# check_error "Failed to change permission for libMoltenVK.dylib"

echo ""
# Sign the Godot app
echo "-----------------------"
echo "Signing $GODOT_APP_NAME.app..."
codesign --force --timestamp --options=runtime --entitlements misc/dist/macos/editor.entitlements -s - $GODOT_APP_NAME.app
check_error "Failed to sign $GODOT_APP_NAME.app"

# Print packaging completion message
echo "$GODOT_APP_NAME packaged and signed successfully."

echo ""
# Check if a symbolic link to the created app exists inside MacOS' Application folder
echo "-----------------------"
APP_LINK="/Applications/$GODOT_APP_NAME-custom.app"
if [ ! -L "$APP_LINK" ]; then
    echo "Creating symbolic link to $GODOT_APP_NAME.app in /Applications folder..."
    sudo ln -s "$(pwd)/$GODOT_APP_NAME.app" "$APP_LINK"
    check_error "Failed to create symbolic link in /Applications folder"
    echo "Symbolic link created successfully."
else
    echo "Symbolic link already exists in /Applications folder."
fi

echo ""
echo "Finished building $GODOT_APP_NAME!"
echo "#######################"
