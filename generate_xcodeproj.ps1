#!/usr/bin/env bash
# 在 MacBook 上生成 Xcode 工程（无需 xcodegen）
# 用法: bash generate_xcodeproj.sh

set -e
cd "$(dirname "$0")"

PROJECT_NAME="Alist"
BUNDLE_ID="com.alist.ios"
DEPLOYMENT_TARGET="16.0"
PROJECT_DIR="$(pwd)"
ALIST_DIR="$PROJECT_DIR/Alist"

mkdir -p "$PROJECT_NAME.xcodeproj"

# 收集所有 swift 文件
SWIFT_FILES=$(find "$ALIST_DIR" -name "*.swift" | sed "s|$PROJECT_DIR/||g" | sort)

# 生成 file references
FILE_REFS=""
BUILD_FILES=""
for f in $SWIFT_FILES; do
    FILE_ID=$(echo "$f" | md5 | cut -c1-24)
    BUILD_ID=$(echo "$f-build" | md5 | cut -c1-24)
    FILE_REFS="$FILE_REFS		$FILE_ID /* $f */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = \"$f\"; sourceTree = \"<group>\"; };
"
    BUILD_FILES="$BUILD_FILES				$BUILD_ID /* $f in Sources */ = {isa = PBXBuildFile; fileRef = $FILE_ID /* $f */; };
"
done

# 生成 group children
GROUP_CHILDREN=""
for f in $SWIFT_FILES; do
    FILE_ID=$(echo "$f" | md5 | cut -c1-24)
    GROUP_CHILDREN="$GROUP_CHILDREN				$FILE_ID /* $f */,
"
done

# Info.plist reference
PLIST_ID="AAAAAAAAAAAAAAAAAAAAAAAA"
FILE_REFS="$FILE_REFS		$PLIST_ID /* Alist/Info.plist */ = {isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = \"Alist/Info.plist\"; sourceTree = \"<group>\"; };"

# 生成 project.pbxproj
cat > "$PROJECT_NAME.xcodeproj/project.pbxproj" << EOF
// !\$*UTF8*\$!
{
	archiveVersion = 1;
	classes = {};
	objectVersion = 56;
	objects = {
/* Begin PBXBuildFile section */
$BUILD_FILES/* End PBXBuildFile section */

/* Begin PBXFileReference section */
$FILE_REFS
/* End PBXFileReference section */

/* Begin PBXGroup section */
		BBBBBBBBBBBBBBBBBBBBBBBB /* Alist */ = {
			isa = PBXGroup;
			children = (
$GROUP_CHILDREN				$PLIST_ID /* Alist/Info.plist */,
			);
			path = Alist;
			sourceTree = "<group>";
		};
		CCCCCCCCCCCCCCCCCCCCCCCC /* Products */ = {
			isa = PBXGroup;
			children = (
				DDDDDDDDDDDDDDDDDDDDDDDD /* $PROJECT_NAME.app */,
			);
			name = Products;
			sourceTree = "<group>";
		};
		EEEEEEEEEEEEEEEEEEEEEEEE /* Project */ = {
			isa = PBXGroup;
			children = (
				BBBBBBBBBBBBBBBBBBBBBBBB /* Alist */,
				CCCCCCCCCCCCCCCCCCCCCCCC /* Products */,
			);
			sourceTree = "<group>";
		};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
		FFFFFFFFFFFFFFFFFFFFFFFF /* $PROJECT_NAME */ = {
			isa = PBXNativeTarget;
			buildConfigurationList = 111111111111111111111111 /* Build configuration list for PBXNativeTarget "$PROJECT_NAME" */;
			buildPhases = (
				222222222222222222222222 /* Sources */,
				333333333333333333333333 /* Resources */,
			);
			buildRules = ();
			dependencies = ();
			name = $PROJECT_NAME;
			productName = $PROJECT_NAME;
			productReference = DDDDDDDDDDDDDDDDDDDDDDDD /* $PROJECT_NAME.app */;
			productType = "com.apple.product-type.application";
		};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
		000000000000000000000000 /* Project object */ = {
			isa = PBXProject;
			buildConfigurationList = 444444444444444444444444 /* Build configuration list for PBXProject "$PROJECT_NAME" */;
			compatibilityVersion = "Xcode 14.0";
			developmentRegion = "zh-Hans";
			hasScannedForEncodings = 0;
			knownRegions = ("zh-Hans", Base);
			mainGroup = EEEEEEEEEEEEEEEEEEEEEEEE /* Project */;
			productRefGroup = CCCCCCCCCCCCCCCCCCCCCCCC /* Products */;
			projectDirPath = "";
			projectRoot = "";
			targets = (
				FFFFFFFFFFFFFFFFFFFFFFFF /* $PROJECT_NAME */,
			);
		};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
		333333333333333333333333 /* Resources */ = {
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = ();
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
		222222222222222222222222 /* Sources */ = {
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
$(echo "$BUILD_FILES" | grep -o '\t\t\t\t[A-F0-9]\{24\} /[^*]*/\*' | sed 's/$/,/')
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXSourcesBuildPhase section */

/* Begin PBXFileReference - Product */
		DDDDDDDDDDDDDDDDDDDDDDDD /* $PROJECT_NAME.app */ = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = $PROJECT_NAME.app; sourceTree = BUILT_PRODUCTS_DIR; };
/* End PBXFileReference - Product */

/* Begin XCBuildConfiguration section */
		555555555555555555555555 /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ENABLE_MODULES = YES;
				"CODE_SIGN_IDENTITY[sdk=macosx*]" = "-";
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = dwarf;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				ENABLE_TESTABILITY = YES;
				GCC_OPTIMIZATION_LEVEL = 0;
				GCC_PREPROCESSOR_DEFINITIONS = "DEBUG=1";
				IPHONEOS_DEPLOYMENT_TARGET = $DEPLOYMENT_TARGET;
				MTL_ENABLE_DEBUG_INFO = YES;
				ONLY_ACTIVE_ARCH = YES;
				SDKROOT = iphoneos;
				SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;
				SWIFT_OPTIMIZATION_LEVEL = "-Onone";
			};
			name = Debug;
		};
		666666666666666666666666 /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ENABLE_MODULES = YES;
				"CODE_SIGN_IDENTITY[sdk=macosx*]" = "-";
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
				ENABLE_NS_ASSERTIONS = NO;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				IPHONEOS_DEPLOYMENT_TARGET = $DEPLOYMENT_TARGET;
				MTL_ENABLE_DEBUG_INFO = NO;
				SDKROOT = iphoneos;
				SWIFT_COMPILATION_MODE = wholemodule;
				SWIFT_OPTIMIZATION_LEVEL = "-O";
				VALIDATE_PRODUCT = YES;
			};
			name = Release;
		};
		777777777777777777777777 /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				GENERATE_INFOPLIST_FILE = NO;
				INFOPLIST_FILE = Alist/Info.plist;
				INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;
				INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;
				INFOPLIST_KEY_UILaunchScreen_Generation = YES;
				INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad = "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
				INFOPLIST_KEY_UISupportedInterfaceOrientations = "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
				LD_RUNPATH_SEARCH_PATHS = "\$(inherited) @executable_path/Frameworks";
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = $BUNDLE_ID;
				PRODUCT_NAME = "\$(TARGET_NAME)";
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = "1,2";
			};
			name = Debug;
		};
		888888888888888888888888 /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				GENERATE_INFOPLIST_FILE = NO;
				INFOPLIST_FILE = Alist/Info.plist;
				INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;
				INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;
				INFOPLIST_KEY_UILaunchScreen_Generation = YES;
				INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad = "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
				INFOPLIST_KEY_UISupportedInterfaceOrientations = "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
				LD_RUNPATH_SEARCH_PATHS = "\$(inherited) @executable_path/Frameworks";
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = $BUNDLE_ID;
				PRODUCT_NAME = "\$(TARGET_NAME)";
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = "1,2";
			};
			name = Release;
		};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
		444444444444444444444444 /* Build configuration list for PBXProject "$PROJECT_NAME" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				555555555555555555555555 /* Debug */,
				666666666666666666666666 /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
		111111111111111111111111 /* Build configuration list for PBXNativeTarget "$PROJECT_NAME" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				777777777777777777777777 /* Debug */,
				888888888888888888888888 /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
/* End XCConfigurationList section */
	};
	rootObject = 000000000000000000000000 /* Project object */;
}
EOF

echo "Generated $PROJECT_NAME.xcodeproj/project.pbxproj"
echo "Swift files:"
echo "$SWIFT_FILES" | wc -l
