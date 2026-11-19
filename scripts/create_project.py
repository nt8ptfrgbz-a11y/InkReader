#!/usr/bin/env python3
"""Regenerate the dependency-free Xcode project using only Python's standard library."""
from pathlib import Path
import hashlib
import json

ROOT = Path(__file__).resolve().parents[1]
objects = {}

class Ref(str):
    pass

def add(key, isa, **fields):
    ident = Ref(hashlib.sha1(key.encode()).hexdigest()[:24].upper())
    objects[ident] = dict(isa=Ref(isa), **fields)
    return ident

def dump(value, depth=0):
    tab = '\t' * depth
    if isinstance(value, Ref): return str(value)
    if isinstance(value, dict):
        return '{\n' + ''.join(f'{tab}\t{json.dumps(str(k), ensure_ascii=False)} = {dump(v, depth+1)};\n' for k,v in value.items()) + tab + '}'
    if isinstance(value, list): return '(\n' + ''.join(f'{tab}\t{dump(v, depth+1)},\n' for v in value) + tab + ')'
    if isinstance(value, int): return str(value)
    return json.dumps(str(value), ensure_ascii=False)

app_sources = sorted((ROOT / 'InkReader').rglob('*.swift'))
test_sources = sorted((ROOT / 'InkReaderUITests').glob('*.swift'))
refs = {}
for path in app_sources + test_sources:
    relative = str(path.relative_to(ROOT))
    refs[relative] = add(relative, 'PBXFileReference', lastKnownFileType='sourcecode.swift', path=relative, sourceTree='<group>')
assets = add('assets', 'PBXFileReference', lastKnownFileType='folder.assetcatalog', path='InkReader/Assets.xcassets', sourceTree='<group>')
novel = add('novel', 'PBXFileReference', lastKnownFileType='net.daringfireball.markdown', path='InkReader/Resources/诛仙同人·长相守.md', sourceTree='<group>')
info = add('info', 'PBXFileReference', lastKnownFileType='text.plist.xml', path='InkReader/Info.plist', sourceTree='<group>')
app_product = add('app-product', 'PBXFileReference', explicitFileType='wrapper.application', includeInIndex=0, path='InkReader.app', sourceTree='BUILT_PRODUCTS_DIR')
test_product = add('test-product', 'PBXFileReference', explicitFileType='wrapper.cfbundle', includeInIndex=0, path='InkReaderUITests.xctest', sourceTree='BUILT_PRODUCTS_DIR')

def phase(key, isa, file_refs):
    files = [add('build-'+key+str(r), 'PBXBuildFile', fileRef=r) for r in file_refs]
    return add(key, isa, buildActionMask=2147483647, files=files, runOnlyForDeploymentPostprocessing=0)

app_phases = [phase('app-sources', 'PBXSourcesBuildPhase', [refs[str(p.relative_to(ROOT))] for p in app_sources]), phase('app-frameworks', 'PBXFrameworksBuildPhase', []), phase('app-resources', 'PBXResourcesBuildPhase', [assets, novel])]
test_phases = [phase('test-sources', 'PBXSourcesBuildPhase', [refs[str(p.relative_to(ROOT))] for p in test_sources]), phase('test-frameworks', 'PBXFrameworksBuildPhase', []), phase('test-resources', 'PBXResourcesBuildPhase', [])]

def configurations(key, extra):
    configs=[]
    for name in ['Debug', 'Release']:
        settings=dict(extra)
        settings.update(SWIFT_OPTIMIZATION_LEVEL='-Onone' if name=='Debug' else '-O', DEBUG_INFORMATION_FORMAT='dwarf' if name=='Debug' else 'dwarf-with-dsym')
        if name=='Debug': settings.update(ENABLE_TESTABILITY='YES', SWIFT_ACTIVE_COMPILATION_CONDITIONS='DEBUG')
        configs.append(add(key+'-'+name, 'XCBuildConfiguration', buildSettings=settings, name=name))
    return add(key+'-configlist', 'XCConfigurationList', buildConfigurations=configs, defaultConfigurationIsVisible=0, defaultConfigurationName='Release')

project_configs=configurations('project', dict(CLANG_ENABLE_MODULES='YES', CLANG_ENABLE_OBJC_ARC='YES', IPHONEOS_DEPLOYMENT_TARGET='17.0', SDKROOT='iphoneos', SWIFT_VERSION='5.0', GCC_C_LANGUAGE_STANDARD='gnu17', CLANG_CXX_LANGUAGE_STANDARD='gnu++20', ENABLE_USER_SCRIPT_SANDBOXING='YES'))
common=dict(CODE_SIGN_STYLE='Automatic', DEVELOPMENT_TEAM='LA5VS444F2', TARGETED_DEVICE_FAMILY='1,2', SUPPORTED_PLATFORMS='iphoneos iphonesimulator', PRODUCT_NAME='$(TARGET_NAME)', CURRENT_PROJECT_VERSION='1', MARKETING_VERSION='1.0', SWIFT_EMIT_LOC_STRINGS='YES')
app_configs=configurations('app', dict(common, INFOPLIST_FILE='InkReader/Info.plist', PRODUCT_BUNDLE_IDENTIFIER='com.edy.inkreader', ASSETCATALOG_COMPILER_APPICON_NAME='AppIcon', ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME='AccentColor', LD_RUNPATH_SEARCH_PATHS=['$(inherited)', '@executable_path/Frameworks']))
test_configs=configurations('test', dict(common, GENERATE_INFOPLIST_FILE='YES', PRODUCT_BUNDLE_IDENTIFIER='com.edy.inkreader.uitests', TEST_TARGET_NAME='InkReader', LD_RUNPATH_SEARCH_PATHS=['$(inherited)', '@executable_path/Frameworks', '@loader_path/Frameworks']))
app_target=add('app-target', 'PBXNativeTarget', buildConfigurationList=app_configs, buildPhases=app_phases, buildRules=[], dependencies=[], name='InkReader', productName='InkReader', productReference=app_product, productType='com.apple.product-type.application')
project_id=Ref(hashlib.sha1(b'project').hexdigest()[:24].upper())
proxy=add('test-proxy', 'PBXContainerItemProxy', containerPortal=project_id, proxyType=1, remoteGlobalIDString=app_target, remoteInfo='InkReader')
dependency=add('test-dependency', 'PBXTargetDependency', target=app_target, targetProxy=proxy)
test_target=add('test-target', 'PBXNativeTarget', buildConfigurationList=test_configs, buildPhases=test_phases, buildRules=[], dependencies=[dependency], name='InkReaderUITests', productName='InkReaderUITests', productReference=test_product, productType='com.apple.product-type.bundle.ui-testing')
app_group=add('app-group', 'PBXGroup', children=[refs[str(p.relative_to(ROOT))] for p in app_sources]+[assets, novel, info], name='InkReader', sourceTree='<group>')
test_group=add('test-group', 'PBXGroup', children=[refs[str(p.relative_to(ROOT))] for p in test_sources], name='InkReaderUITests', sourceTree='<group>')
products=add('products', 'PBXGroup', children=[app_product, test_product], name='Products', sourceTree='<group>')
main_group=add('main-group', 'PBXGroup', children=[app_group, test_group, products], sourceTree='<group>')
add('project', 'PBXProject', attributes=dict(LastUpgradeCheck='2700', BuildIndependentTargetsInParallel='YES', TargetAttributes={app_target:dict(CreatedOnToolsVersion='27.1'),test_target:dict(CreatedOnToolsVersion='27.1', TestTargetID=app_target)}), buildConfigurationList=project_configs, compatibilityVersion='Xcode 14.0', developmentRegion='zh_CN', hasScannedForEncodings=0, knownRegions=['zh_CN','en','Base'], mainGroup=main_group, productRefGroup=products, projectDirPath='', projectRoot='', targets=[app_target,test_target])
project_dir=ROOT / 'InkReader.xcodeproj'
project_dir.mkdir(exist_ok=True)
(project_dir/'project.pbxproj').write_text('// !$*UTF8*$!\n'+dump(dict(archiveVersion=1,classes={},objectVersion=56,objects=objects,rootObject=project_id))+'\n')

def reference(ident, name, product):
    return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{ident}" BuildableName="{product}" BlueprintName="{name}" ReferencedContainer="container:InkReader.xcodeproj"/>'
app_ref=reference(app_target,'InkReader','InkReader.app')
test_ref=reference(test_target,'InkReaderUITests','InkReaderUITests.xctest')
scheme=f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2700" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries>
<BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{app_ref}</BuildActionEntry>
<BuildActionEntry buildForTesting="YES" buildForRunning="NO" buildForProfiling="NO" buildForArchiving="NO" buildForAnalyzing="NO">{test_ref}</BuildActionEntry>
</BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO">{test_ref}</TestableReference></Testables></TestAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{app_ref}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{app_ref}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>'''
scheme_dir=project_dir/'xcshareddata/xcschemes'
scheme_dir.mkdir(parents=True,exist_ok=True)
(scheme_dir/'InkReader.xcscheme').write_text(scheme)
print('Generated InkReader.xcodeproj')
