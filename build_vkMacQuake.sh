#!/usr/bin/env zsh 

# ANSI color codes
PURPLE='\033[0;35m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# This just gets the location of the folder where the script is run from. 
SCRIPT_DIR=${0:a:h}
cd "$SCRIPT_DIR"

# Introduction
echo "${PURPLE}This script is for creating a native macOS build of ${GREEN}Quake${PURPLE} or ${GREEN}Arcane Dimensions${NC}\n"
echo "${PURPLE}Place the script alongside the ${GREEN}id1${PURPLE} and/or ${GREEN}ad${PURPLE} game data folders and run it from there${NC}\n"

echo "${PURPLE}It requires ${GREEN}Homebrew ${PURPLE}and the ${GREEN}Xcode command-line tools ${PURPLE}installed${NC}"
echo "${PURPLE}If they are not present you will be prompted to install them${NC}\n"

# Functions
check_data() {
	if [[ -d $1 ]]; then 
		echo "${GREEN}Found $1 folder${NC}"
	else 
		echo "${RED}Could not find $1 folder...\nQuitting...${NC}"
		exit 1
	fi
}


PS3='Which version would you like to build? '
OPTIONS=(
	"Quake"
	"Arcane Dimensions"
	"Quit")
select opt in $OPTIONS[@]
do
	case $opt in
		"Quake")
			GAME_ID="vkmacquake"
			GAME_LAUNCH="quake"
			GAME_TITLE="Quake"
			PKGINFO_TITLE="VKMQ"
			ICON_URL='https://parsefiles.back4app.com/JPaQcFfEEQ1ePBxbf6wvzkPMEqKYHhPYv8boI1Rc/1d79cbcdd7d6e1d59f437b1a79db9f2f_Q0SQBf1rNB.icns'
			check_data id1
			break
			;;
		"Arcane Dimensions")
			GAME_ID="arcane"
			GAME_LAUNCH="ad"
			GAME_TITLE="Arcane Dimensions"
			PKGINFO_TITLE="MQAD"
			ICON_URL='https://parsefiles.back4app.com/JPaQcFfEEQ1ePBxbf6wvzkPMEqKYHhPYv8boI1Rc/ac5ea73ff0371b4ce4a379f0fff344f8_Quake__Arcane_Dimensions.icns'
			check_data id1
			check_data ad
			break
			;;
		"Quit")
			echo -e "${PURPLE}Quitting${NC}"
			exit 0
			;;
		*) 
		echo "\"$REPLY\" is not one of the options..."
		echo "Enter the number of the option and press enter to select"
		;;
	esac
done

# Check if Homebrew is installed
if ! command -v brew &> /dev/null; then
	echo -e "${PURPLE}Homebrew not found. Installing Homebrew...${NC}"
	/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
	(echo; echo 'eval "$(/opt/homebrew/bin/brew shellenv)"') >> $HOME/.zprofile
	eval "$(/opt/homebrew/bin/brew shellenv)"
	
	if [ $? -ne 0 ]; then
		echo "${RED}There was an issue installing Homebrew${NC}"
		echo "${PURPLE}Quitting...${NC}"	
		exit 1
	fi
else
	echo -e "${PURPLE}Homebrew found. Updating Homebrew...${NC}"
	brew update
fi

## Homebrew dependencies
# Install required dependencies
echo -e "${PURPLE}Checking for Homebrew dependencies...${NC}"
brew_dependency_check() {
	if [ -d "$(brew --prefix)/opt/$1" ]; then
		echo -e "${GREEN}Found $1. Checking for updates...${NC}"
			brew upgrade $1
	else
		 echo -e "${PURPLE}Did not find $1. Installing...${NC}"
		brew install $1
	fi
}

# Required Homebrew packages
deps=( dylibbundler flac glslang libvorbis mad meson molten-vk opus opusfile pkgconfig sdl2 spirv-tools vulkan-headers zopfli )

for dep in $deps[@]
do 
	brew_dependency_check $dep
done

if [ ! -d "vkMacQuake" ]; then
	echo "${PURPLE}Cloning repository${NC}\n"
	git clone https://github.com/atsb/vkMacQuake.git

	#Check for errors
	if [ $? -ne 0 ]; then
	echo "${RED}There was an issue cloning the repository${NC}"
	echo "${PURPLE}Quitting...${NC}"	
	exit 1
	fi
	
	cd vkMacQuake
	
	# delete function that creates history.txt on exit
	sed -i='' '813,831d' Quake/keys.c
else 
	echo "${PURPLE}vkMacQuake folder found${NC}"
	cd vkMacQuake
	rm -rf build
	git pull origin master
fi

# Build
meson setup build && ninja -C build

#Check for errors
if [ $? -ne 0 ]; then
	echo "${RED}There was an issue compiling the app${NC}"
	echo "${PURPLE}Quitting...${NC}"	
	exit 1
fi

# Create app bundle structure
rm -rf "${GAME_TITLE}.app"
mkdir -p "${GAME_TITLE}.app/Contents/Resources"
mkdir -p "${GAME_TITLE}.app/Contents/MacOS"

# create Info.plist
PLIST="<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">
<plist version=\"1.0\">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>English</string>
	<key>CFBundleGetInfoString</key>
	<string>${GAME_TITLE}</string>
	<key>CFBundleExecutable</key>
	<string>launch_${GAME_ID}.sh</string>
	<key>CFBundleIconFile</key>
	<string>${GAME_ID}.icns</string>
	<key>CFBundleIdentifier</key>
	<string>com.github.atsb.${GAME_ID}</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>${GAME_TITLE}</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>1</string>
	<key>CFBundleVersion</key>
	<string>1.30.1</string>
	<key>LSMinimumSystemVersion</key>
	<string>11.0</string>
	<key>NSPrincipalClass</key>
	<string>NSApplication</string>
	<key>NSHumanReadableCopyright</key>
	<string>© 1996 id software</string>
	<key>NSHighResolutionCapable</key>
	<true/>
	<key>LSApplicationCategoryType</key>
	<string>public.app-category.games</string>
</dict>
</plist>
"
echo "${PLIST}" > "${GAME_TITLE}.app/Contents/Info.plist"

# Create PkgInfo
PKGINFO="-n APPL${PKGINFO_TITLE}"
echo "${PKGINFO}" > "${GAME_TITLE}.app/Contents/PkgInfo"

# Create launch script. This allows passing the dir and set executable permissions
LAUNCHER="#!/usr/bin/env zsh

SCRIPT_DIR=\${0:a:h}
cd "\$SCRIPT_DIR"

./vkmacquake -basedir . -game ${GAME_LAUNCH}"
echo "${LAUNCHER}" > "${GAME_TITLE}.app/Contents/MacOS/launch_${GAME_ID}.sh"
chmod +x "${GAME_TITLE}.app/Contents/MacOS/launch_${GAME_ID}.sh"

# Bundle resources
echo "${PURPLE}Copying resources into app bundle...${NC}"	
cp -R ../id1 ./build/vkmacquake ${GAME_TITLE}.app/Contents/MacOS/

if [[ $GAME_ID == "arcane" ]]; then
	cp -R ../ad ${GAME_TITLE}.app/Contents/MacOS/
fi

#Check for errors
if [ $? -ne 0 ]; then
	echo "${RED}There was an issue creating the app bundle${NC}"
	echo "${PURPLE}Quitting...${NC}"	
	exit 1
fi

if [[ -a ${GAME_ID}1024.png ]]; then 
	# Create icon if there is a file called ${GAME_ID}1024.png in the build folder
	echo -e "${PURPLE}Found image file. Creating icon...${NC}"
	
	mkdir ${GAME_ID}.iconset
	sips -z 16 16     ${GAME_ID}1024.png --out ${GAME_ID}.iconset/icon_16x16.png
	sips -z 32 32     ${GAME_ID}1024.png --out ${GAME_ID}.iconset/icon_16x16@2x.png
	sips -z 32 32     ${GAME_ID}1024.png --out ${GAME_ID}.iconset/icon_32x32.png
	sips -z 64 64     ${GAME_ID}1024.png --out ${GAME_ID}.iconset/icon_32x32@2x.png
	sips -z 128 128   ${GAME_ID}1024.png --out ${GAME_ID}.iconset/icon_128x128.png
	sips -z 256 256   ${GAME_ID}1024.png --out ${GAME_ID}.iconset/icon_128x128@2x.png
	sips -z 256 256   ${GAME_ID}1024.png --out ${GAME_ID}.iconset/icon_256x256.png
	sips -z 512 512   ${GAME_ID}1024.png --out ${GAME_ID}.iconset/icon_256x256@2x.png
	sips -z 512 512   ${GAME_ID}1024.png --out ${GAME_ID}.iconset/icon_512x512.png
	cp ${GAME_ID}1024.png ${GAME_ID}.iconset/icon_512x512@2x.png
	iconutil -c icns ${GAME_ID}.iconset
	rm -R ${GAME_ID}.iconset
	cp -R ${GAME_ID}.icns "${GAME_TITLE}.app/Contents/Resources/"

else 
	# Otherwise get an icon from macosicons.com
	curl -o ${GAME_TITLE}.app/Contents/Resources/${GAME_ID}.icns https://parsefiles.back4app.com/JPaQcFfEEQ1ePBxbf6wvzkPMEqKYHhPYv8boI1Rc/15de8486fbe09dcfdbb53df418751cc9_CoYnVMBvxU.icns
fi

#Check for errors
if [ $? -ne 0 ]; then
	echo "${RED}There was an issue getting a game icon${NC}"
	echo "${PURPLE}Continuing without one...${NC}"	
fi

# Bundle libs & Codesign
dylibbundler -of -cd -b -x ./${GAME_TITLE}.app/Contents/MacOS/vkmacquake -d ./${GAME_TITLE}.app/Contents/libs/
codesign --force --deep --sign - ${GAME_TITLE}.app

#Check for errors
if [ $? -ne 0 ]; then
	echo "${RED}There was an issue bundling the dependencies${NC}"
	echo "${PURPLE}Quitting...${NC}"	
	exit 1
fi

# Cleanup
cp -a ${GAME_TITLE}.app .. && cd ..
rm -rf vkMacQuake	