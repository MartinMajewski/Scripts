#!/bin/bash
# Copyright (c) 2025 Martin Majewski
# Email: mail@martinmajewski.net
# Website: https://www.martinmajewski.net

# Variables
GODOT_APP_NAME="Godot"
PRECISION="double"
MONO_ENABLED=false

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
    echo ""
    echo "Current working directory: $(pwd)"
    check_error "Failed to change directory out of Scripts folder"
fi

###################################################################################################
# Ask the user if they want to build Godot with or without DotNet/Mono support
echo ""
echo "====================================================="
echo "Do you want to build Godot with DotNet/Mono support?"
echo "1. Yes"
echo "2. No"
echo "====================================================="
echo ""
echo "Note: Building with DotNet/Mono support requires the Mono SDK to be installed."
echo ""
read -p "Enter your choice (1 or 2): " choice

# Set the MONO_ENABLED variable based on user input
if [ "$choice" -eq 1 ]; then
    MONO_ENABLED=true
    GODOT_APP_NAME="Godot-Mono"
    echo "Building Godot with DotNet/Mono support."
elif [ "$choice" -eq 2 ]; then
    MONO_ENABLED=false
    GODOT_APP_NAME="Godot"
    echo "Building Godot without DotNet/Mono support."
else
    echo "Invalid choice. Exiting."
    exit 1
fi


# Ask the user if they want to use double or single precision
echo ""
echo "====================================================="
echo "Do you want to use double or single precision?"
echo "1. Double"
echo "2. Single"
echo "====================================================="
echo ""
read -p "Enter your choice (1 or 2): " precision_choice
echo ""

# Set the PRECISION variable based on user input
if [ "$precision_choice" -eq 1 ]; then
    PRECISION="double"
    echo "Using double precision."
elif [ "$precision_choice" -eq 2 ]; then
    PRECISION="single"
    echo "Using single precision."
else
    echo "Invalid choice. Exiting."
    exit 1
fi
###################################################################################################

###################################################################################################
# Print the build configuration
echo ""
echo "#######################"
echo "Build Configuration:"
echo "GODOT_APP_NAME: $GODOT_APP_NAME"
echo "PRECISION: $PRECISION"
echo "MONO_ENABLED: $MONO_ENABLED"
echo "#######################"
echo ""
echo "Starting build in 3 seconds..."
for i in {3..1}; do
    echo "$i..."
    sleep 1
done
###################################################################################################

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
echo "Installing/checking Vulkan SDK..."
./misc/scripts/install_vulkan_sdk_macos.sh
check_error "Failed to install Vulkan SDK"

echo ""
# Build the Godot engine for MacOS arm64 with Vulkan support
echo "-----------------------"
scons platform=macos arch=arm64 volk=yes module_mono_enabled=yes precision=$PRECISION
check_error "Failed to build the Godot engine"

echo ""
# Build export templates
echo "-----------------------"
scons platform=macos target=template_debug module_mono_enabled=yes precision=$PRECISION
check_error "Failed to build template_debug"
scons platform=macos target=template_release module_mono_enabled=yes precision=$PRECISION
check_error "Failed to build template_release"

# Print compile completion message
echo "$GODOT_APP_NAME build for MacOS arm64 completed successfully."

if [ "$MONO_ENABLED" = true ]; then
    echo ""
    # Generate Mono Glue
    echo "-----------------------"
    echo "Generating Mono Glue..."
    if [ "$PRECISION" = "double" ]; then
        bin/godot.macos.editor.double.arm64.mono --headless --generate-mono-glue modules/mono/glue
    else
        bin/godot.macos.editor.arm64.mono --headless --generate-mono-glue modules/mono/glue
    fi
    check_error "Failed to generate Mono Glue"

    echo ""
    # Build Managed Libraries
    echo "-----------------------"
    echo "Building Managed Libraries..."
    ./modules/mono/build_scripts/build_assemblies.py --godot-output-dir=./bin --push-nupkgs-local ~/Developer/DotNet/local_nuget_source --precision=$PRECISION
fi
###################################################################################################
echo ""
# Package the Godot engine for MacOS
echo "-----------------------"
echo "Packaging $GODOT_APP_NAME for MacOS arm64..."

echo "Removing old $GODOT_APP_NAME.app..."
rm -rf $GODOT_APP_NAME.app
check_error "Failed to remove old $GODOT_APP_NAME.app"

echo "Copying macos_tools.app template as $GODOT_APP_NAME.app to $pwd ..."
cp -r misc/dist/macos_tools.app ./$GODOT_APP_NAME.app
check_error "Failed to copy macos_tools.app"

###################################################################################################
echo ""
echo "Creating Contents/MacOS directory..."
mkdir -p $GODOT_APP_NAME.app/Contents/MacOS
check_error "Failed to create Contents/MacOS directory"

echo ""
echo "Copying $GODOT_Name binary to $GODOT_APP_NAME.app/Contents/MacOS/..."
if [ "$MONO_ENABLED" = true ]; then
    if [ "$PRECISION" = "double" ]; then
        cp bin/godot.macos.editor.double.arm64.mono $GODOT_APP_NAME.app/Contents/MacOS/Godot
    else
        cp bin/godot.macos.editor.arm64.mono $GODOT_APP_NAME.app/Contents/MacOS/Godot
    fi
    check_error "Failed to copy $GODOT_Name binary!"

    echo ""
    echo "Copying GodotSharp to $GODOT_APP_NAME.app/Contents/Resources/..."
    cp -rp bin/GodotSharp $GODOT_APP_NAME.app/Contents/Resources/
    check_error "Failed to copy GodotSharp to $GODOT_APP_NAME.app/Contents/Resources/"
else
    if [ "$PRECISION" = "double" ]; then
        cp bin/godot.macos.editor.double.arm64 $GODOT_APP_NAME.app/Contents/MacOS/Godot
    else
        cp bin/godot.macos.editor.arm64 $GODOT_APP_NAME.app/Contents/MacOS/Godot
    fi
    check_error "Failed to copy $GODOT_Name binary!"
fi

###################################################################################################
echo ""
echo "Changing permission to 755 for $GODOT_APP_NAME..."
chmod +x $GODOT_APP_NAME.app/Contents/MacOS/Godot
check_error "Failed to change permission for $GODOT_APP_NAME"

###################################################################################################
echo ""
# Sign the Godot app
echo "-----------------------"
echo "Signing $GODOT_APP_NAME.app..."
codesign --force --timestamp --options=runtime --entitlements misc/dist/macos/editor.entitlements -s - $GODOT_APP_NAME.app
check_error "Failed to sign $GODOT_APP_NAME.app"
# Print packaging completion message
echo "$GODOT_APP_NAME packaged and signed successfully."

###################################################################################################
echo ""
# Check if a symbolic link to the created app exists inside MacOS' Application folder
echo "-----------------------"
APP_LINK="/Applications/$GODOT_APP_NAME-CustomBuild.app"
if [ ! -L "$APP_LINK" ]; then
    echo "Creating symbolic link to $GODOT_APP_NAME.app in /Applications folder..."
    sudo ln -s "$(pwd)/$GODOT_APP_NAME.app" "$APP_LINK"
    check_error "Failed to create symbolic link in /Applications folder"
    echo "Symbolic link created successfully."
else
    echo "Symbolic link already exists in /Applications folder."
fi

###################################################################################################
echo ""
echo "Finished building $GODOT_APP_NAME!"
echo "#######################"
