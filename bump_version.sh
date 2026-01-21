#!/usr/bin/env bash
set -e

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

NOCOLOR='\033[0m'
RED='\033[0;31m'
GREEN='\033[0;32m'

get_git_tag() {
    git describe --tags $(git rev-list --tags='v[0-9].[0-9]*' --max-count=1) 2> /dev/null
}

get_git_commit() {
    git rev-parse --short HEAD
}

error () {
    echo -e "${RED}$1${NOCOLOR}"
}

okay () {
    echo -e "${GREEN}$1${NOCOLOR}"
}

on_failure () {
    if [ $1 -ne 0 ]; then
    error "$2 [Return code was not zero but $1.]"
    exit
fi
}
######### SEMVER VALIDATION
# https://github.com/fsaintjacques/semver-tool/blob/master/src/semver
# SEMVER_REGEX=""

function validate-version {
    if [[ $1 =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-((0|[1-9][0-9]*|[0-9]*[a-zA-Z-][0-9a-zA-Z-]*)(\.(0|[1-9][0-9]*|[0-9]*[a-zA-Z-][0-9a-zA-Z-]*))*))?(\+([0-9a-zA-Z-]+(\.[0-9a-zA-Z-]+)*))?$ ]]; then
        echo ""
    else
        error "Version '$1' does not follow correct semver scheme 'X.Y.Z(-PRERELEASE)(+BUILD)'."
        exit
    fi
}
#####################################

if [[ $(git diff --stat) != '' ]]; then
    error "Repo has unclean state"
    exit
fi

OLD_VERSION=$(get_git_tag | cut -d 'v' -f 2)

exec 3>&1;
VERSION=$(dialog --title "Bump Version" --inputbox "New Version (Tag)" 0 0 "${OLD_VERSION} <old>" 2>&1 1>&3);
exitcode=$?;
exec 3>&-;

VERSION=$(echo $VERSION | xargs) # strip white spaces
# check if roughly correct semver
validate-version "$VERSION"

if [ $exitcode -eq 0 ]
then

    if [ "$VERSION" = "$OLD_VERSION" ] || [ "$VERSION" = "${OLD_VERSION} <old>" ]; then
        error "Please use a new version (following semver)"
        exit
    fi

    okay "Bumping version to: $VERSION " 
else 
    error "Could not get tag" >&2
    exit
fi

source ./backend/.venv/bin/activate
on_failure $? "Couldn't activate zest environment"

cd $SCRIPT_DIR
cd backend
uv version ${VERSION}
echo "__version__ = '${VERSION}'" > app/version.py
cd ../frontend
cider version ${VERSION}+$(($(git rev-list --count HEAD) + 2000))
sed -i "s/pkgver=.*$/pkgver=${VERSION}/g" PKGBUILD
cd ..
git add backend/pyproject.toml
git add backend/app/version.py
git add frontend/pubspec.yaml
git add frontend/PKGBUILD
git commit -m "Bumping version to ${VERSION}" --no-verify
git tag v${VERSION}
git push
git push --tags
