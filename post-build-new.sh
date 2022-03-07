APP_DOCKER_REPO=$1
APP_MANIFEST=$2
REPO="gunish-dt/devtronRelease"
GIT_REPO="github.com/$REPO.git"
GIT_CONFIG_EMAIL="gunish@devtron.ai"
GIT_CONFIG_NAME="gunish-dt"
GIT_USERNAME="gunish-dt"
GITHUB_TOKENS=$3
GIT_BRANCH="main"
RAW_GIT_REPO="https:\/\/raw.githubusercontent.com\/gunish-dt\/devtronRelease\/"
VERSION_FILE="manifests/version.txt"
RELEASE_BRANCH="release-bot"
MIGRATOR_FILE="migrator.yaml"
DEVTRON_MIGRATOR_LINE="43"
CASBIN_MIGRATOR_LINE="84"
#Getting the commits
BUILD_COMMIT=$(git rev-parse HEAD)
echo "=======================GUNISH=========================="
echo $BUILD_COMMIT
echo $DOCKER_IMAGE_TAG
echo "========================check================================"
mkdir preci
cd preci
wget https://github.com/cli/cli/releases/download/v1.5.0/gh_1.5.0_linux_386.tar.gz -O ghcli.tar.gz
tar --strip-components=1 -xf ghcli.tar.gz
echo "=============================after cli download======================="
echo $GITHUB_TOKENS > tokens.txt
echo "===========================check token======================="
bin/gh auth login --with-token < tokens.txt
echo "================================authentication==============="
bin/gh repo clone "$REPO"
echo "========================================repo clone command above==="
cd devtronRelease
git checkout "$GIT_BRANCH"
git checkout -b "$RELEASE_BRANCH"
git pull origin "$RELEASE_BRANCH"
echo "============ ls -la========"
ls -la
#Updating Image in the yaml
sed -i "s/quay.io\/devtron\/$APP_DOCKER_REPO:.*/quay.io\/devtron\/$APP_DOCKER_REPO:$DOCKER_IMAGE_TAG\"/" manifests/yamls/$APP_MANIFEST

#VERIFYING MANIFEST
cat manifests/yamls/$APP_MANIFEST

#Setting Git configurations
git config --global user.email "$GIT_CONFIG_EMAIL"
git config --global user.name "$GIT_CONFIG_NAME"
echo "https://raw.githubusercontent.com/$REPO/$GIT_BRANCH/$VERSION_FILE"
DEV_RELEASE=$(curl -L -s  "https://raw.githubusercontent.com/$REPO/$GIT_BRANCH/$VERSION_FILE" )
RELEASE_VERSION=$(../bin/gh release list -L 1 -R $REPO | awk '{print $1}')

#Comparing version mentioned in the version.txt with latest release version
if [[ $DEV_RELEASE == $RELEASE_VERSION ]]
  then
    #RELEASE_VERSION=$(../bin/gh release list -L 1 -R $REPO | awk '{print $1}')
    NEXT_RELEASE_VERSION=$(echo ${DEV_RELEASE} | awk -F. -v OFS=. '{$NF++;print}')
    echo "NEXTVERSION from inside loop: $NEXT_RELEASE_VERSION"
    sed -i "s/$DEV_RELEASE/$NEXT_RELEASE_VERSION/" $VERSION_FILE
  else
    NEXT_RELEASE_VERSION=$DEV_RELEASE
    echo "NEXTVERSION from inside ESLE: $NEXT_RELEASE_VERSION"
fi
#Updating LTAG Version in the installation-script
sed -i "s/LTAG=.*/LTAG=\"$NEXT_RELEASE_VERSION\";/" manifests/installation-script
#Updating latest installation-script URL in the devtron-installer.yaml
sed -i "s/url:.*/url: $RAW_GIT_REPO$NEXT_RELEASE_VERSION\/manifests\/installation-script/" manifests/install/devtron-installer.yaml

# ========== Updating the Migration script with latest commit hash ==========
sed -i "$DEVTRON_MIGRATOR_LINE s/value.*/value: $BUILD_COMMIT/" manifests/yamls/$MIGRATOR_FILE
sed -i "$CASBIN_MIGRATOR_LINE s/value.*/value: $BUILD_COMMIT/" manifests/yamls/$MIGRATOR_FILE

git commit -am "Updated latest image of $APP_DOCKER_REPO in the installer"
git push -f https://$GIT_USERNAME:$GITHUB_TOKENS@$GIT_REPO --all
#Creating Release ######################
#RELEASE_RESPONSE=$(../bin/gh release create $NEXT_RELEASE_VERSION --target $RELEASE_BRANCH -R $REPO)
#echo "FINAL RELEASE RESPONSE: $RELEASE_RESPONSE"
#Creating PR into main branch
PR_RESPONSE=$(../bin/gh pr create --title "RELEASE: PR for $NEXT_RELEASE_VERSION" --body "Updates in $APP_DOCKER_REPO micro-service" --base $GIT_BRANCH --head $RELEASE_BRANCH --repo $REPO)
echo "FINAL PR RESPONSE: $PR_RESPONSE"
