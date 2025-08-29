#!/usr/bin/env bash
# shellcheck disable=SC1091,2154

set -e

# include common functions
. ./utils.sh

if [[ "${VSCODE_QUALITY}" == "insider" ]]; then
  cp -rp src/insider/* vscode/
else
  cp -rp src/stable/* vscode/
fi

cp -f LICENSE vscode/LICENSE.txt

cd vscode || { echo "'vscode' dir not found"; exit 1; }

../update_settings.sh

# apply patches
{ set +x; } 2>/dev/null

echo "APP_NAME=\"${APP_NAME}\""
echo "APP_NAME_LC=\"${APP_NAME_LC}\""
echo "BINARY_NAME=\"${BINARY_NAME}\""
echo "GH_REPO_PATH=\"${GH_REPO_PATH}\""
echo "ORG_NAME=\"${ORG_NAME}\""

for file in ../patches/*.patch; do
  if [[ -f "${file}" ]]; then
    apply_patch "${file}"
  fi
done

if [[ "${VSCODE_QUALITY}" == "insider" ]]; then
  for file in ../patches/insider/*.patch; do
    if [[ -f "${file}" ]]; then
      apply_patch "${file}"
    fi
  done
fi

if [[ -d "../patches/${OS_NAME}/" ]]; then
  for file in "../patches/${OS_NAME}/"*.patch; do
    if [[ -f "${file}" ]]; then
      apply_patch "${file}"
    fi
  done
fi

for file in ../patches/user/*.patch; do
  if [[ -f "${file}" ]]; then
    apply_patch "${file}"
  fi
done

set -x

export ELECTRON_SKIP_BINARY_DOWNLOAD=1
export PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1

if [[ "${OS_NAME}" == "linux" ]]; then
  export VSCODE_SKIP_NODE_VERSION_CHECK=1

   if [[ "${npm_config_arch}" == "arm" ]]; then
    export npm_config_arm_version=7
  fi
elif [[ "${OS_NAME}" == "windows" ]]; then
  if [[ "${npm_config_arch}" == "arm" ]]; then
    export npm_config_arm_version=7
  fi
else
  if [[ "${CI_BUILD}" != "no" ]]; then
    clang++ --version
  fi
fi

mv .npmrc .npmrc.bak
cp ../npmrc .npmrc

for i in {1..5}; do # try 5 times
  if [[ "${CI_BUILD}" != "no" && "${OS_NAME}" == "osx" ]]; then
    CXX=clang++ npm ci && break
  else
    npm ci && break
  fi

  if [[ $i == 5 ]]; then
    echo "Npm install failed too many times" >&2
    exit 1
  fi
  echo "Npm install failed $i, trying again..."

  sleep $(( 15 * (i + 1)))
done

mv .npmrc.bak .npmrc

setpath() {
  local jsonTmp
  { set +x; } 2>/dev/null
  jsonTmp=$( jq --arg 'value' "${3}" "setpath(path(.${2}); \$value)" "${1}.json" )
  echo "${jsonTmp}" > "${1}.json"
  set -x
}

setpath_json() {
  local jsonTmp
  { set +x; } 2>/dev/null
  jsonTmp=$( jq --argjson 'value' "${3}" "setpath(path(.${2}); \$value)" "${1}.json" )
  echo "${jsonTmp}" > "${1}.json"
  set -x
}

# product.json
cp product.json{,.bak}

setpath "product" "checksumFailMoreInfoUrl" "https://go.microsoft.com/fwlink/?LinkId=828886"
setpath "product" "documentationUrl" "https://go.microsoft.com/fwlink/?LinkID=533484#vscode"
setpath_json "product" "extensionsGallery" '{"serviceUrl": "https://open-vsx.org/vscode/gallery", "itemUrl": "https://open-vsx.org/vscode/item", "extensionUrlTemplate": "https://open-vsx.org/vscode/gallery/{publisher}/{name}/latest", "controlUrl": "https://raw.githubusercontent.com/EclipseFdn/publish-extensions/refs/heads/master/extension-control/extensions.json"}'
setpath "product" "introductoryVideosUrl" "https://go.microsoft.com/fwlink/?linkid=832146"
setpath "product" "keyboardShortcutsUrlLinux" "https://go.microsoft.com/fwlink/?linkid=832144"
setpath "product" "keyboardShortcutsUrlMac" "https://go.microsoft.com/fwlink/?linkid=832143"
setpath "product" "keyboardShortcutsUrlWin" "https://go.microsoft.com/fwlink/?linkid=832145"
setpath "product" "licenseUrl" "https://github.com/VSCodium/vscodium/blob/master/LICENSE"
setpath_json "product" "linkProtectionTrustedDomains" '["https://open-vsx.org"]'
setpath "product" "releaseNotesUrl" "https://go.microsoft.com/fwlink/?LinkID=533483#vscode"
setpath "product" "reportIssueUrl" "https://github.com/VSCodium/vscodium/issues/new"
setpath "product" "requestFeatureUrl" "https://go.microsoft.com/fwlink/?LinkID=533482"
setpath "product" "tipsAndTricksUrl" "https://go.microsoft.com/fwlink/?linkid=852118"
setpath "product" "twitterUrl" "https://go.microsoft.com/fwlink/?LinkID=533687"
setpath "product" "documentationUrl" "https://github.com/tdhungit/jcode#readme"
setpath "product" "licenseUrl" "https://github.com/tdhungit/jcode/blob/main/LICENSE"
setpath_json "product" "linkProtectionTrustedDomains" '["https://open-vsx.org"]'
setpath "product" "releaseNotesUrl" "https://github.com/tdhungit/jcode/releases"
setpath "product" "reportIssueUrl" "https://github.com/tdhungit/jcode/issues/new"
setpath "product" "requestFeatureUrl" "https://github.com/tdhungit/jcode/issues/new?labels=enhancement"
setpath "product" "tipsAndTricksUrl" "https://github.com/tdhungit/jcode#tips-and-tricks"
setpath "product" "twitterUrl" "https://github.com/tdhungit/jcode"

if [[ "${DISABLE_UPDATE}" != "yes" ]]; then
  setpath "product" "updateUrl" "https://raw.githubusercontent.com/VSCodium/versions/refs/heads/master"

  if [[ "${VSCODE_QUALITY}" == "insider" ]]; then
  setpath "product" "downloadUrl" "https://github.com/tdhungit/jcode/releases"
  else
    setpath "product" "downloadUrl" "https://github.com/VSCodium/vscodium/releases"
  fi
fi

if [[ "${VSCODE_QUALITY}" == "insider" ]]; then
  setpath "product" "nameShort" "JCode - Insiders"
  setpath "product" "nameLong" "JCode - Insiders"
  setpath "product" "applicationName" "jcode-insiders"
  setpath "product" "dataFolderName" ".jcode-insiders"
  setpath "product" "linuxIconName" "jcode-insiders"
  setpath "product" "quality" "insider"
  setpath "product" "urlProtocol" "jcode-insiders"
  setpath "product" "serverApplicationName" "jcode-server-insiders"
  setpath "product" "serverDataFolderName" ".jcode-server-insiders"
  setpath "product" "darwinBundleIdentifier" "com.tdhungit.JCodeInsiders"
  setpath "product" "win32AppUserModelId" "JCode.JCodeInsiders"
  setpath "product" "win32DirName" "JCode Insiders"
  setpath "product" "win32MutexName" "jcodeinsiders"
  setpath "product" "win32NameVersion" "JCode Insiders"
  setpath "product" "win32RegValueName" "JCodeInsiders"
  setpath "product" "win32ShellNameShort" "JCode Insiders"
  setpath "product" "win32AppId" "{253467AB-3901-4B72-B7B0-E25B9D7FA8D2}"
  setpath "product" "win32x64AppId" "{BD1B9A8B-5736-4EF4-A664-D268DAF43C5F}"
  setpath "product" "win32arm64AppId" "{35C57A7A-EC97-47E7-B696-A059F93C6105}"
  setpath "product" "win32UserAppId" "{ADF25A89-6B34-4207-93F8-0B64868D06F6}"
  setpath "product" "win32x64UserAppId" "{71C6B2B0-5878-458C-9217-6C2F043EB340}"
  setpath "product" "win32arm64UserAppId" "{D5780BA6-56D4-41A9-846D-2D9CA972A67E}"
  setpath "product" "tunnelApplicationName" "jcode-tunnel-insiders"
  setpath "product" "win32TunnelServiceMutex" "jcodeinsiders-tunnelservice"
  setpath "product" "win32TunnelMutex" "jcodeinsiders-tunnel"
  setpath "product" "win32ContextMenu.x64.clsid" "091C70B0-287D-4D40-AD6C-44784D2ADED6"
  setpath "product" "win32ContextMenu.arm64.clsid" "DF7C53A6-A97E-456D-8177-B0D052D311C6"
else
  setpath "product" "nameShort" "JCode"
  setpath "product" "nameLong" "JCode"
  setpath "product" "applicationName" "jcode"
  setpath "product" "linuxIconName" "jcode"
  setpath "product" "quality" "stable"
  setpath "product" "urlProtocol" "jcode"
  setpath "product" "serverApplicationName" "jcode-server"
  setpath "product" "serverDataFolderName" ".jcode-server"
  setpath "product" "darwinBundleIdentifier" "com.tdhungit.JCode"
  setpath "product" "win32AppUserModelId" "JCode.JCode"
  setpath "product" "win32DirName" "JCode"
  setpath "product" "win32MutexName" "jcode"
  setpath "product" "win32NameVersion" "JCode"
  setpath "product" "win32RegValueName" "JCode"
  setpath "product" "win32ShellNameShort" "JCode"
  setpath "product" "win32AppId" "{5D9DF95B-6EC8-4CB6-BE8D-BF3B6E87DDCC}"
  setpath "product" "win32x64AppId" "{69BB4156-9F1D-4DDA-96F1-D6A74B2746B5}"
  setpath "product" "win32arm64AppId" "{C1031408-857C-483E-83F6-6E2C9E32EF90}"
  setpath "product" "win32UserAppId" "{ADF25A89-6B34-4207-93F8-0B64868D06F6}"
  setpath "product" "win32x64UserAppId" "{71C6B2B0-5878-458C-9217-6C2F043EB340}"
  setpath "product" "win32arm64UserAppId" "{D5780BA6-56D4-41A9-846D-2D9CA972A67E}"
  setpath "product" "tunnelApplicationName" "jcode-tunnel"
  setpath "product" "win32TunnelServiceMutex" "jcode-tunnelservice"
  setpath "product" "win32TunnelMutex" "jcode-tunnel"
  setpath "product" "win32ContextMenu.x64.clsid" "F551BC22-A5D0-40A1-BAC8-1C5D952AFE12"
  setpath "product" "win32ContextMenu.arm64.clsid" "56023381-63F2-4F38-97D6-84AD321E3D71"
fi

jsonTmp=$( jq -s '.[0] * .[1]' product.json ../product.json )
echo "${jsonTmp}" > product.json && unset jsonTmp

cat product.json

# package.json
cp package.json{,.bak}

setpath "package" "version" "${RELEASE_VERSION%-insider}"

replace 's|Microsoft Corporation|VSCodium|' package.json
replace 's|Microsoft Corporation|JCode Team|' package.json

cp resources/server/manifest.json{,.bak}

if [[ "${VSCODE_QUALITY}" == "insider" ]]; then
  setpath "resources/server/manifest" "name" "VSCodium - Insiders"
  setpath "resources/server/manifest" "short_name" "VSCodium - Insiders"
else
  setpath "resources/server/manifest" "name" "VSCodium"
  setpath "resources/server/manifest" "short_name" "VSCodium"
fi
setpath "resources/server/manifest" "name" "JCode - Insiders"
setpath "resources/server/manifest" "short_name" "JCode - Insiders"

# announcements
replace "s|\\[\\/\\* BUILTIN_ANNOUNCEMENTS \\*\\/\\]|$( tr -d '\n' < ../announcements-builtin.json )|" src/vs/workbench/contrib/welcomeGettingStarted/browser/gettingStarted.ts

../undo_telemetry.sh

replace 's|Microsoft Corporation|VSCodium|' build/lib/electron.js
replace 's|Microsoft Corporation|VSCodium|' build/lib/electron.ts
replace 's|([0-9]) Microsoft|\1 VSCodium|' build/lib/electron.js
replace 's|([0-9]) Microsoft|\1 VSCodium|' build/lib/electron.ts
replace 's|Microsoft Corporation|JCode Team|' build/lib/electron.js
replace 's|Microsoft Corporation|JCode Team|' build/lib/electron.ts
replace 's|([0-9]) Microsoft|\1 JCode Team|' build/lib/electron.js
replace 's|([0-9]) Microsoft|\1 JCode Team|' build/lib/electron.ts

if [[ "${OS_NAME}" == "linux" ]]; then
  # microsoft adds their apt repo to sources
  # unless the app name is code-oss
  # as we are renaming the application to vscodium
  # we need to edit a line in the post install template
  if [[ "${VSCODE_QUALITY}" == "insider" ]]; then
    sed -i "s/code-oss/codium-insiders/" resources/linux/debian/postinst.template
  else
    sed -i "s/code-oss/codium/" resources/linux/debian/postinst.template
  fi

  # fix the packages metadata
  # code.appdata.xml
  sed -i 's|Visual Studio Code|VSCodium|g' resources/linux/code.appdata.xml
  sed -i 's|https://code.visualstudio.com/docs/setup/linux|https://github.com/VSCodium/vscodium#download-install|' resources/linux/code.appdata.xml
  sed -i 's|https://code.visualstudio.com/home/home-screenshot-linux-lg.png|https://vscodium.com/img/vscodium.png|' resources/linux/code.appdata.xml
  sed -i 's|https://code.visualstudio.com|https://vscodium.com|' resources/linux/code.appdata.xml
  sed -i 's|Visual Studio Code|JCode|g' resources/linux/code.appdata.xml
  sed -i 's|https://code.visualstudio.com/docs/setup/linux|https://github.com/tdhungit/jcode#download-install|' resources/linux/code.appdata.xml
  sed -i 's|https://code.visualstudio.com/home/home-screenshot-linux-lg.png|https://github.com/tdhungit/jcode/raw/main/logo.png|' resources/linux/code.appdata.xml
  sed -i 's|https://code.visualstudio.com|https://github.com/tdhungit/jcode|' resources/linux/code.appdata.xml

  # control.template
  sed -i 's|Microsoft Corporation <vscode-linux@microsoft.com>|VSCodium Team https://github.com/VSCodium/vscodium/graphs/contributors|'  resources/linux/debian/control.template
  sed -i 's|Visual Studio Code|VSCodium|g' resources/linux/debian/control.template
  sed -i 's|https://code.visualstudio.com/docs/setup/linux|https://github.com/VSCodium/vscodium#download-install|' resources/linux/debian/control.template
  sed -i 's|https://code.visualstudio.com|https://vscodium.com|' resources/linux/debian/control.template
  sed -i 's|Microsoft Corporation <vscode-linux@microsoft.com>|JCode Team https://github.com/tdhungit/jcode/graphs/contributors|'  resources/linux/debian/control.template
  sed -i 's|Visual Studio Code|JCode|g' resources/linux/debian/control.template
  sed -i 's|https://code.visualstudio.com/docs/setup/linux|https://github.com/tdhungit/jcode#download-install|' resources/linux/debian/control.template
  sed -i 's|https://code.visualstudio.com|https://github.com/tdhungit/jcode|' resources/linux/debian/control.template

  # code.spec.template
  sed -i 's|Microsoft Corporation|VSCodium Team|' resources/linux/rpm/code.spec.template
  sed -i 's|Visual Studio Code Team <vscode-linux@microsoft.com>|VSCodium Team https://github.com/VSCodium/vscodium/graphs/contributors|' resources/linux/rpm/code.spec.template
  sed -i 's|Visual Studio Code|VSCodium|' resources/linux/rpm/code.spec.template
  sed -i 's|https://code.visualstudio.com/docs/setup/linux|https://github.com/VSCodium/vscodium#download-install|' resources/linux/rpm/code.spec.template
  sed -i 's|https://code.visualstudio.com|https://vscodium.com|' resources/linux/rpm/code.spec.template
  sed -i 's|Microsoft Corporation|JCode Team|' resources/linux/rpm/code.spec.template
  sed -i 's|Visual Studio Code Team <vscode-linux@microsoft.com>|JCode Team https://github.com/tdhungit/jcode/graphs/contributors|' resources/linux/rpm/code.spec.template
  sed -i 's|Visual Studio Code|JCode|' resources/linux/rpm/code.spec.template
  sed -i 's|https://code.visualstudio.com/docs/setup/linux|https://github.com/tdhungit/jcode#download-install|' resources/linux/rpm/code.spec.template
  sed -i 's|https://code.visualstudio.com|https://github.com/tdhungit/jcode|' resources/linux/rpm/code.spec.template

  # snapcraft.yaml
  sed -i 's|Visual Studio Code|VSCodium|'  resources/linux/rpm/code.spec.template
  sed -i 's|Visual Studio Code|JCode|'  resources/linux/rpm/code.spec.template
elif [[ "${OS_NAME}" == "windows" ]]; then
  # code.iss
  sed -i 's|https://code.visualstudio.com|https://vscodium.com|' build/win32/code.iss
  sed -i 's|Microsoft Corporation|VSCodium|' build/win32/code.iss
  sed -i 's|https://code.visualstudio.com|https://github.com/tdhungit/jcode|' build/win32/code.iss
  sed -i 's|Microsoft Corporation|JCode Team|' build/win32/code.iss
fi

cd ..
