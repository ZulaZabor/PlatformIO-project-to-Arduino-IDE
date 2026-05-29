# werkend script voor MacOs Monteray
# PlatformIO project to Arduino IDE script
# Naar een Idee van Geoffrey May 6, 2021
# gemaakt door ZulaZabor 29 mei 2026
#
# Ga in de dir staan van het PlatformIO project
# Start de Terminal en Type 
# nano make-arduino.sh dan kopieer de onderstaande code in de edittor
# sluit af met ctrl O <enter> en ctrl X In de terminal type
# chmod +x make-arduino.sh nu kun je het starten met ./make-arduino.sh

# ==============================================================================
#  0. PROJECTNAAM EN VERSIE PLUS CONTROLE 
# ==============================================================================

# Vraag om de projectnaam en controleer deze
read -p "Enter project name: " projectName

if [ -z "$projectName" ]
then
    echo "Error: please add a project name"
    exit 1
fi

# MAP-CHECK: Controleer of de projectmap daadwerkelijk bestaat
if [ ! -d "./$projectName" ]; then
    echo "Error: De projectmap '$projectName' bestaat niet in deze map."
    echo "Zorg dat je dit script uitvoert vanuit de hoofdmap waar je projecten in staan."
    exit 1
fi

# Ga de projectmap in
cd "$projectName"

# CONTROLE: Zit de src map in deze projectmap?
if [ ! -d "./src" ]; then
    echo "Error: Geen './src' map gevonden binnenin '$projectName'!"
    exit 1
fi

# Vraag om de versie en controleer deze
read -p "Enter version: " version

if [ -z "$version" ]
then
    echo "Error: please add a version"
    exit 1
fi

# Als beide zijn ingevuld, start het script
echo "----------------------------------------"
echo "Starting build process..."
echo "Project Name: $projectName"
echo "Version:      $version"
echo "----------------------------------------"

# Strings vervangen (Array)
stringReplacements=("s/string to be replaced/replacement string/g")

# Maak build-map aan
mkdir -p build

# Hoofdprogramma map aanmaken
mainName="$projectName-$version"
mkdir -p "build/$mainName"

# ==============================================================================
#  1. BESTANDEN KOPIËREN UIT ./lib (Alleen uit zichtbare src-mappen)
# ==============================================================================
if [ -d "./lib" ]; then
    find "./lib" -type d -name "src" ! -path '*/.*' | while read -r srcDir; do
        find "$srcDir" -maxdepth 1 -mindepth 1 ! -name ".*" -exec cp -r {} "build/$mainName/" \; 2>/dev/null
    done
fi

# ==============================================================================
#  2. BESTANDEN KOPIËREN UIT ./src (Zonder verborgen bestanden uit de hoofdmap)
# ==============================================================================
if [ -d "./src" ]; then
    find "./src" -maxdepth 1 -mindepth 1 ! -name ".*" -exec cp -r {} "build/$mainName/" \; 2>/dev/null
fi

# Rename main.cpp naar .ino (met safety check)
if [ -f "build/$mainName/main.cpp" ]; then
    mv "build/$mainName/main.cpp" "build/$mainName/$mainName.ino"
fi

# ROBUUSTE SED VERVANGING: Alleen uitvoeren als er daadwerkelijk bestanden zijn
for ((i = 0; i < ${#stringReplacements[@]}; i++))
do
    find "build/$mainName" -type f \( -name "*.cpp" -o -name "*.h" -o -name "*.ino" \) ! -path '*/.*' | while read 
-r file; do
        sed -i '' "${stringReplacements[$i]}" "$file"
    done
done

# ==============================================================================
#  3. KOPPIEER LIBRARIES UIT .PIO (Exclusief verborgen bestanden en cache)
# ==============================================================================
mkdir -p "build/$mainName/libs"
if [ -d ./.pio/libdeps ]; then
    find ./.pio/libdeps -mindepth 1 -maxdepth 2 -type d -exec cp -R {} "build/$mainName/libs/" \; 2>/dev/null
fi

# ==============================================================================
#  4. DE-DUPLICEREN EN OPRUIMEN ESP32 EN ESP32DEV
# ==============================================================================
for targetDir in "build/$mainName/libs/esp32" "build/$mainName/libs/esp32dev"
do
    if [ -d "$targetDir" ]; then
        for libPath in "$targetDir"/*
        do
            if [ -d "$libPath" ]; then
                libName=$(basename "$libPath")
                
                # Als er al een library in libs/ bevindt: wis de nieuwe
                if [ -d "build/$mainName/libs/$libName" ]; then
                    rm -rf "$libPath"
                else
                    # Anders: verplaats de nieuwe library naar libs/
                    mv "$libPath" "build/$mainName/libs/" 2>/dev/null
                fi
            fi
        done

        # Wissen van integrity.dat bestanden in esp32 en esp32dev
   
        rm -f "build/$mainName/libs/esp32/integrity.dat" 2>/dev/null
        rm -f "build/$mainName/libs/esp32dev/integrity.dat" 2>/dev/null        

        # Controleer daarna of esp32 en/of esp32dev leeg zijn, als dat zo is wis de dir
        if [ -z "$(find "$targetDir" -mindepth 1 -maxdepth 1 ! -name '.*')" ]; then
            rm -rf "$targetDir"
        fi
    fi
done

# ==============================================================================
#  5 BESTANDEN GESCHIKT MAKEN OM IN Aduino/linraries TE PLAATSEN
# ==============================================================================

# Spaties vervangen door underscores in lib-namen
for i in "build/$mainName/libs"/*
do
    if [ -e "$i" ]; then
        mv "$i" "${i// /_}" 2>/dev/null
    fi
done

# ==============================================================================
#  6. KOPIEER DATA FOLDER EN ZIP RESULTAAT
# ==============================================================================
# Kopieer data folder
if [ -d "./data" ]; then
    mkdir -p "build/$mainName/data"
    cp -R ./data/* "build/$mainName/data" 2>/dev/null
fi

# Zip het resultaat
zip -r "build/$mainName.zip" "build/$mainName"

# Eindoverzicht tonen
echo "----------------------------------------"
echo "Build successfully completed!"
echo "Project:  $projectName"
echo "Version:  $version"
echo "Output:   $projectName/build/$mainName.zip"
echo "----------------------------------------"

