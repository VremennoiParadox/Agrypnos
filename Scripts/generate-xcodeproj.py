#!/usr/bin/env python3
"""Emit a compact Xcode project that compiles the menu-bar app against AgrypnosCore."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "Apps/Agrypnos"
SOURCES = sorted((APP / "Sources").rglob("*.swift"))
rel_sources = [str(p.relative_to(APP)) for p in SOURCES]

def hid(name: str) -> str:
    import hashlib
    return hashlib.sha1(name.encode()).hexdigest()[:24].upper()

proj = hid("project")
target = hid("target")
sources_phase = hid("sources_phase")
frameworks_phase = hid("frameworks_phase")
resources_phase = hid("resources_phase")
app_ref = hid("app_ref")
src_group = hid("src_group")
res_group = hid("res_group")
prod_group = hid("prod_group")
main_group = hid("main_group")
cfg_list_proj = hid("cfg_list_proj")
cfg_list_tgt = hid("cfg_list_tgt")
cfg_proj_d = hid("cfg_proj_d")
cfg_proj_r = hid("cfg_proj_r")
cfg_tgt_d = hid("cfg_tgt_d")
cfg_tgt_r = hid("cfg_tgt_r")
pkg_ref = hid("pkg_ref")
pkg_prod = hid("pkg_prod")
core_fw = hid("core_fw")
info_ref = hid("info_ref")
ent_ref = hid("ent_ref")
assets_ref = hid("assets_ref")
grant_ref = hid("grant_ref")
assets_bf = hid("assets_bf")
grant_bf = hid("grant_bf")

file_ids = {}
build_ids = {}
for rel in rel_sources:
    file_ids[rel] = hid("file:" + rel)
    build_ids[rel] = hid("build:" + rel)

folder_groups = {}
for rel in rel_sources:
    parent = str(Path(rel).parent)
    if parent not in folder_groups:
        folder_groups[parent] = hid("group:" + parent)

lines = []
w = lines.append
w("// !$*UTF8*$!")
w("{")
w("	archiveVersion = 1;")
w("	classes = {")
w("	};")
w("	objectVersion = 56;")
w("	objects = {")
w("")
w("/* Begin PBXBuildFile section */")
for rel in rel_sources:
    w(f"		{build_ids[rel]} /* {Path(rel).name} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_ids[rel]} /* {Path(rel).name} */; }};")
w(f"		{core_fw} /* AgrypnosCore in Frameworks */ = {{isa = PBXBuildFile; productRef = {pkg_prod} /* AgrypnosCore */; }};")
w(f"		{assets_bf} /* Assets.xcassets in Resources */ = {{isa = PBXBuildFile; fileRef = {assets_ref} /* Assets.xcassets */; }};")
w(f"		{grant_bf} /* grant.sh in Resources */ = {{isa = PBXBuildFile; fileRef = {grant_ref} /* grant.sh */; }};")
w("/* End PBXBuildFile section */")
w("")
w("/* Begin PBXFileReference section */")
w(f"		{app_ref} /* Agrypnos.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = Agrypnos.app; sourceTree = BUILT_PRODUCTS_DIR; }};")
for rel in rel_sources:
    name = Path(rel).name
    quoted = name if name.replace("_", "").replace(".", "").replace("-", "").isalnum() else f'"{name}"'
    w(f"		{file_ids[rel]} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {quoted}; sourceTree = \"<group>\"; }};")
w(f"		{info_ref} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = \"<group>\"; }};")
w(f"		{ent_ref} /* Agrypnos.entitlements */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = Agrypnos.entitlements; sourceTree = \"<group>\"; }};")
w(f"		{assets_ref} /* Assets.xcassets */ = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = \"<group>\"; }};")
w(f"		{grant_ref} /* grant.sh */ = {{isa = PBXFileReference; lastKnownFileType = text.script.sh; path = grant.sh; sourceTree = \"<group>\"; }};")
w("/* End PBXFileReference section */")
w("")
w("/* Begin PBXFrameworksBuildPhase section */")
w(f"		{frameworks_phase} /* Frameworks */ = {{")
w("			isa = PBXFrameworksBuildPhase;")
w("			buildActionMask = 2147483647;")
w("			files = (")
w(f"				{core_fw} /* AgrypnosCore in Frameworks */,")
w("			);")
w("			runOnlyForDeploymentPostprocessing = 0;")
w("		};")
w("/* End PBXFrameworksBuildPhase section */")
w("")
w("/* Begin PBXGroup section */")
# source subgroups
by_parent = {}
for rel in rel_sources:
    by_parent.setdefault(str(Path(rel).parent), []).append(rel)

w(f"		{src_group} /* Sources */ = {{")
w("			isa = PBXGroup;")
w("			children = (")
# top-level swift + folder groups
top_files = by_parent.get("Sources", [])
for rel in top_files:
    w(f"				{file_ids[rel]} /* {Path(rel).name} */,")
for parent, gid in sorted(folder_groups.items()):
    if parent == "Sources":
        continue
    name = Path(parent).name
    w(f"				{gid} /* {name} */,")
w("			);")
w("			path = Sources;")
w("			sourceTree = \"<group>\";")
w("		};")

for parent, gid in sorted(folder_groups.items()):
    if parent == "Sources":
        continue
    w(f"		{gid} /* {Path(parent).name} */ = {{")
    w("			isa = PBXGroup;")
    w("			children = (")
    for rel in by_parent.get(parent, []):
        w(f"				{file_ids[rel]} /* {Path(rel).name} */,")
    w("			);")
    w(f"			path = {Path(parent).name};")
    w("			sourceTree = \"<group>\";")
    w("		};")

w(f"		{res_group} /* Resources */ = {{")
w("			isa = PBXGroup;")
w("			children = (")
w(f"				{assets_ref} /* Assets.xcassets */,")
w(f"				{info_ref} /* Info.plist */,")
w(f"				{ent_ref} /* Agrypnos.entitlements */,")
w(f"				{grant_ref} /* grant.sh */,")
w("			);")
w("			path = Resources;")
w("			sourceTree = \"<group>\";")
w("		};")
w(f"		{prod_group} /* Products */ = {{")
w("			isa = PBXGroup;")
w("			children = (")
w(f"				{app_ref} /* Agrypnos.app */,")
w("			);")
w("			name = Products;")
w("			sourceTree = \"<group>\";")
w("		};")
w(f"		{main_group} = {{")
w("			isa = PBXGroup;")
w("			children = (")
w(f"				{src_group} /* Sources */,")
w(f"				{res_group} /* Resources */,")
w(f"				{prod_group} /* Products */,")
w("			);")
w("			sourceTree = \"<group>\";")
w("		};")
w("/* End PBXGroup section */")
w("")
w("/* Begin PBXNativeTarget section */")
w(f"		{target} /* Agrypnos */ = {{")
w("			isa = PBXNativeTarget;")
w("			buildConfigurationList = %s /* Build configuration list for PBXNativeTarget \"Agrypnos\" */;" % cfg_list_tgt)
w("			buildPhases = (")
w(f"				{sources_phase} /* Sources */,")
w(f"				{frameworks_phase} /* Frameworks */,")
w(f"				{resources_phase} /* Resources */,")
w("			);")
w("			buildRules = (")
w("			);")
w("			dependencies = (")
w("			);")
w("			name = Agrypnos;")
w("			packageProductDependencies = (")
w(f"				{pkg_prod} /* AgrypnosCore */,")
w("			);")
w("			productName = Agrypnos;")
w(f"			productReference = {app_ref} /* Agrypnos.app */;")
w("			productType = \"com.apple.product-type.application\";")
w("		};")
w("/* End PBXNativeTarget section */")
w("")
w("/* Begin PBXProject section */")
w(f"		{proj} /* Project object */ = {{")
w("			isa = PBXProject;")
w("			attributes = {")
w("				BuildIndependentTargetsInParallel = 1;")
w("				LastSwiftUpdateCheck = 1500;")
w("				LastUpgradeCheck = 1500;")
w("			};")
w(f"			buildConfigurationList = {cfg_list_proj} /* Build configuration list for PBXProject \"Agrypnos\" */;")
w("			compatibilityVersion = \"Xcode 14.0\";")
w("			developmentRegion = en;")
w("			hasScannedForEncodings = 0;")
w("			knownRegions = (")
w("				en,")
w("				Base,")
w("			);")
w(f"			mainGroup = {main_group};")
w("			packageReferences = (")
w(f"				{pkg_ref} /* XCLocalSwiftPackageReference \"../..\" */,")
w("			);")
w("			productRefGroup = %s /* Products */;" % prod_group)
w("			projectDirPath = \"\";")
w("			projectRoot = \"\";")
w("			targets = (")
w(f"				{target} /* Agrypnos */,")
w("			);")
w("		};")
w("/* End PBXProject section */")
w("")
w("/* Begin PBXResourcesBuildPhase section */")
w(f"		{resources_phase} /* Resources */ = {{")
w("			isa = PBXResourcesBuildPhase;")
w("			buildActionMask = 2147483647;")
w("			files = (")
w(f"				{assets_bf} /* Assets.xcassets in Resources */,")
w(f"				{grant_bf} /* grant.sh in Resources */,")
w("			);")
w("			runOnlyForDeploymentPostprocessing = 0;")
w("		};")
w("/* End PBXResourcesBuildPhase section */")
w("")
w("/* Begin PBXSourcesBuildPhase section */")
w(f"		{sources_phase} /* Sources */ = {{")
w("			isa = PBXSourcesBuildPhase;")
w("			buildActionMask = 2147483647;")
w("			files = (")
for rel in rel_sources:
    w(f"				{build_ids[rel]} /* {Path(rel).name} in Sources */,")
w("			);")
w("			runOnlyForDeploymentPostprocessing = 0;")
w("		};")
w("/* End PBXSourcesBuildPhase section */")
w("")

common_proj = """
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				COPY_PHASE_STRIP = NO;
				DEAD_CODE_STRIPPING = YES;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				GCC_NO_COMMON_BLOCKS = YES;
				MACOSX_DEPLOYMENT_TARGET = 14.0;
				SDKROOT = macosx;
				SWIFT_VERSION = 5.0;
"""
common_tgt = f"""
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				CODE_SIGN_ENTITLEMENTS = Resources/Agrypnos.entitlements;
				CODE_SIGN_IDENTITY = "-";
				CODE_SIGN_STYLE = Automatic;
				COMBINE_HIDPI_IMAGES = YES;
				CURRENT_PROJECT_VERSION = 1;
				DEAD_CODE_STRIPPING = YES;
				ENABLE_HARDENED_RUNTIME = YES;
				GENERATE_INFOPLIST_FILE = NO;
				INFOPLIST_FILE = Resources/Info.plist;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/../Frameworks",
				);
				MACOSX_DEPLOYMENT_TARGET = 14.0;
				MARKETING_VERSION = 0.1.0;
				PRODUCT_BUNDLE_IDENTIFIER = app.agrypnos.Agrypnos;
				PRODUCT_NAME = Agrypnos;
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_STRICT_CONCURRENCY = complete;
				SWIFT_VERSION = 5.0;
"""

w("/* Begin XCBuildConfiguration section */")
w(f"		{cfg_proj_d} /* Debug */ = {{")
w("			isa = XCBuildConfiguration;")
w("			buildSettings = {")
w(common_proj)
w("				DEBUG_INFORMATION_FORMAT = dwarf;")
w("				ENABLE_TESTABILITY = YES;")
w("				GCC_DYNAMIC_NO_PIC = NO;")
w("				GCC_OPTIMIZATION_LEVEL = 0;")
w("				ONLY_ACTIVE_ARCH = YES;")
w("				SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;")
w("				SWIFT_OPTIMIZATION_LEVEL = \"-Onone\";")
w("			};")
w("			name = Debug;")
w("		};")
w(f"		{cfg_proj_r} /* Release */ = {{")
w("			isa = XCBuildConfiguration;")
w("			buildSettings = {")
w(common_proj)
w("				DEBUG_INFORMATION_FORMAT = \"dwarf-with-dsym\";")
w("				SWIFT_COMPILATION_MODE = wholemodule;")
w("				SWIFT_OPTIMIZATION_LEVEL = \"-O\";")
w("			};")
w("			name = Release;")
w("		};")
w(f"		{cfg_tgt_d} /* Debug */ = {{")
w("			isa = XCBuildConfiguration;")
w("			buildSettings = {")
w(common_tgt)
w("			};")
w("			name = Debug;")
w("		};")
w(f"		{cfg_tgt_r} /* Release */ = {{")
w("			isa = XCBuildConfiguration;")
w("			buildSettings = {")
w(common_tgt)
w("			};")
w("			name = Release;")
w("		};")
w("/* End XCBuildConfiguration section */")
w("")
w("/* Begin XCConfigurationList section */")
w(f"		{cfg_list_proj} /* Build configuration list for PBXProject \"Agrypnos\" */ = {{")
w("			isa = XCConfigurationList;")
w("			buildConfigurations = (")
w(f"				{cfg_proj_d} /* Debug */,")
w(f"				{cfg_proj_r} /* Release */,")
w("			);")
w("			defaultConfigurationIsVisible = 0;")
w("			defaultConfigurationName = Release;")
w("		};")
w(f"		{cfg_list_tgt} /* Build configuration list for PBXNativeTarget \"Agrypnos\" */ = {{")
w("			isa = XCConfigurationList;")
w("			buildConfigurations = (")
w(f"				{cfg_tgt_d} /* Debug */,")
w(f"				{cfg_tgt_r} /* Release */,")
w("			);")
w("			defaultConfigurationIsVisible = 0;")
w("			defaultConfigurationName = Release;")
w("		};")
w("/* End XCConfigurationList section */")
w("")
w("/* Begin XCLocalSwiftPackageReference section */")
w(f"		{pkg_ref} /* XCLocalSwiftPackageReference \"../..\" */ = {{")
w("			isa = XCLocalSwiftPackageReference;")
w("			relativePath = ../..;")
w("		};")
w("/* End XCLocalSwiftPackageReference section */")
w("")
w("/* Begin XCSwiftPackageProductDependency section */")
w(f"		{pkg_prod} /* AgrypnosCore */ = {{")
w("			isa = XCSwiftPackageProductDependency;")
w(f"			package = {pkg_ref} /* XCLocalSwiftPackageReference \"../..\" */;")
w("			productName = AgrypnosCore;")
w("		};")
w("/* End XCSwiftPackageProductDependency section */")
w("	};")
w(f"	rootObject = {proj} /* Project object */;")
w("}")

out = APP / "Agrypnos.xcodeproj" / "project.pbxproj"
out.parent.mkdir(parents=True, exist_ok=True)
out.write_text("\n".join(lines) + "\n")
print(f"Wrote {out} ({len(lines)} lines, {len(rel_sources)} swift files)")
for rel in rel_sources:
    print(" ", rel)
