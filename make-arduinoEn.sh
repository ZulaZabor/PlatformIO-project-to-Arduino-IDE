# Working script for macOS Monterey
# PlatformIO project to Arduino IDE script
# Based on an idea by Geoffrey May 6, 2021
# Created by ZulaZabor May 29, 2026
#
# Navigate to the PlatformIO project directory
# Open the Terminal and type:
# nano make-arduino.sh then copy the code below into the editor
# Save and exit with Ctrl+O <enter> and Ctrl+X. In the terminal type:
# chmod +x make-arduino.sh now you can run it using ./make-arduino.sh

# ==============================================================================
#  0. PROJECT NAME, VERSION, AND VALIDATION
# ==============================================================================

# Prompt for project name and validate it
read -p "Enter project name: " projectName

if [ -z "$projectName" ]
then
    echo "Error: please add a project name"
    exit 1
fi

# DIRECTORY CHECK: Verify if the project folder actually exists
if [ ! -d "./$projectName" ]; then
    echo "Error: The project directory '$projectName' does not exist in this folder."
    echo "Make sure you run this script from the root directory containing your projects."
    exit 1
fi

# Navigate into the project directory
cd "$projectName"

# VALIDATION: Check if the src folder exists inside this project directory
if [ ! -d "./src" ]; then
    echo "Error: No './src' directory found inside '$projectName'!"
    exit 1
fi

# Prompt for version and validate it
read -p "Enter version: " version

if [ -z "$version" ]
then
    echo "Error: please add a version"
    exit 1
fi

# If both inputs are valid, start the script
echo "----------------------------------------"
echo "Starting build process..."
echo "Project Name: $projectName"
echo "Version:      $version"
echo "----------------------------------------"

# String replacements (Array)
stringReplacements=("s/string to be replaced/replacement string/g")

# Create build directory
mkdir -p build

# Create main program directory
mainName="$projectName-$version"
mkdir -p "build/$mainName"

# ==============================================================================
#  1. COPY FILES FROM ./lib (Visible src folders only)
# ==============================================================================
if [ -d "./lib" ]; then
    find "./lib" -type d -name "src" ! -path '*/.*' | while read -r srcDir; do
        find "$srcDir" -maxdepth 1 -mindepth 1 ! -name ".*" -exec cp -r {} "build/$mainName/" \; 2>/dev/null
    done
fi

# ==============================================================================
#  2. COPY FILES FROM ./src (Excluding hidden files from the root folder)
# ==============================================================================
if [ -d "./src" ]; then
    find "./src" -maxdepth 1 -mindepth 1 ! -name ".*" -exec cp -r {} "build/$mainName/" \; 2>/dev/null
fi

# Rename main.cpp to .ino (with safety check)
if [ -f "build/$mainName/main.cpp" ]; then
    mv "build/$mainName/main.cpp" "build/$mainName/$mainName.ino"
fi

# ROBUST SED REPLACEMENT: Run only if files actually exist
for ((i = 0; i < ${#stringReplacements[@]}; i++))
do
    find "build/$mainName" -type f \( -name "*.cpp" -o -name "*.h" -o -name "*.ino" \) ! -path '*/.*' | while read 
-r file; do
        sed -i '' "${stringReplacements[$i]}" "$file"
    done
done

# ==============================================================================
#  3. COPY LIBRARIES FROM .PIO (Excluding hidden files and cache)
# ==============================================================================
mkdir -p "build/$mainName/libs"
if [ -d ./.pio/libdeps ]; then
    find ./.pio/libdeps -mindepth 1 -maxdepth 2 -type d -exec cp -R {} "build/$mainName/libs/" \; 2>/dev/null
fi

# ==============================================================================
#  4. DE-DUPLICATE AND CLEAN UP ESP32 AND ESP32DEV
# ==============================================================================
for targetDir in "build/$mainName/libs/esp32" "build/$mainName/libs/esp32dev"
do
    if [ -d "$targetDir" ]; then
        for libPath in "$targetDir"/*
        do
            if [ -d "$libPath" ]; then
                libName=$(basename "$libPath")
                
                # If the library already exists in libs/: delete the duplicate
                if [ -d "build/$mainName/libs/$libName" ]; then
                    rm -rf "$libPath"
                else
                    # Otherwise: move the new library into libs/
                    mv "$libPath" "build/$mainName/libs/" 2>/dev/null
                fi
            fi
        done

        # Delete integrity.dat files in esp32 and esp32dev
   
        rm -f "build/$mainName/libs/esp32/integrity.dat" 2>/dev/null
        rm -f "build/$mainName/libs/esp32dev/integrity.dat" 2>/dev/null        

        # Check if esp32 and/or esp32dev are empty; if so, delete the directory
        if [ -z "$(find "$targetDir" -mindepth 1 -maxdepth 1 ! -name '.*')" ]; then
            rm -rf "$targetDir"
        fi
    fi
done

# ==============================================================================
#  5. FORMAT FILES FOR ARDUINO LIBRARIES DIRECTORY
# ==============================================================================

# Replace spaces with underscores in library names
for i in "build/$mainName/libs"/*
do
    if [ -e "$i" ]; then
        mv "$i" "${i// /_}" 2>/dev/null
    fi
done

# ==============================================================================
#  6. COPY DATA FOLDER AND ZIP THE RESULT
# ==============================================================================
# Copy data folder
if [ -d "./data" ]; then
    mkdir -p "build/$mainName/data"
    cp -R ./data/* "build/$mainName/data" 2>/dev/null
fi

# Zip the final output
zip -r "build/$mainName.zip" "build/$mainName"

# Display final build summary
echo "----------------------------------------"
echo "Build successfully completed!"
echo "Project:  $projectName"
echo "Version:  $version"
echo "Output:   $projectName/build/$mainName.zip"
echo "----------------------------------------"