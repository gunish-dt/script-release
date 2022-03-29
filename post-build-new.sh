APP_DOCKER_REPO=$DOCKER_REPO
APP_MANIFEST=$MANIFEST
HYPERION_APP_MANIFEST="values.yaml"
REPO=$REPOSITORY
GIT_REPO="github.com/$REPO.git"
HYPERION_REPO=$HYPERION_REPOSITORY
HYPERION_GIT_REPO="github.com/$HYPERION_REPO.git"
GIT_CONFIG_EMAIL=$GIT_CONFIG_EMAIL
GIT_CONFIG_NAME=$GIT_CONFIG_NAME
GIT_USERNAME=$GIT_USERNAME
GITHUB_TOKENS=$PAT
GIT_BRANCH=$GIT_BRANCH
RAW_GIT_REPO=$RAW_GIT_REPO
VERSION_FILE=$VERSION_FILE
RELEASE_BRANCH=$RELEASE_BRANCH
MIGRATOR_FILE=$MIGRATOR_FILE
DEVTRON_MIGRATOR_LINE=$DEVTRON_MIGRATOR_LINE
CASBIN_MIGRATOR_LINE=$CASBIN_MIGRATOR_LINE
VERSION_FILE_HYPERION="charts/devtron/values.yaml"
VERSION_FILE_CHART="charts/devtron/Chart.yaml"
HYPERION_DEVTRON_MIGRATOR_LINE=$HYPERION_DEVTRON_MIGRATOR_LINE
HYPERION_CASBIN_MIGRATOR_LINE=$HYPERION_CASBIN_MIGRATOR_LINE

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



echo "=================If else check from migration======================="
if [[ $DEVTRON_MIGRATOR_LINE == "x" && $CASBIN_MIGRATOR_LINE == "x" ]]
  then
   echo "No Migration Changes"
  else 
# ========== Updating the Migration script with latest commit hash ==========
    echo "Migration hash update"
    sed -i "$DEVTRON_MIGRATOR_LINE s/value.*/value: $BUILD_COMMIT/" manifests/yamls/$MIGRATOR_FILE
    sed -i "$CASBIN_MIGRATOR_LINE s/value.*/value: $BUILD_COMMIT/" manifests/yamls/$MIGRATOR_FILE

fi
echo "=================If else end for migration======================="

git commit -am "Updated latest image of $APP_DOCKER_REPO in the installer"
git push -f https://$GIT_USERNAME:$GITHUB_TOKENS@$GIT_REPO --all
#Creating Release ######################

PR_RESPONSE=$(../bin/gh pr create --title "RELEASE: PR for $NEXT_RELEASE_VERSION" --body "Updates in $APP_DOCKER_REPO micro-service" --base $GIT_BRANCH --head $RELEASE_BRANCH --repo $REPO)
echo "FINAL PR RESPONSE: $PR_RESPONSE"


echo "==============================Hyperion Repo==========================="
cd ..
ls
pwd
echo "=============================checking files=========================="
bin/gh repo clone "gunish-dt/hyperionRelease"
cd hyperionRelease
git checkout "$GIT_BRANCH"
git checkout -b "$RELEASE_BRANCH"
git pull origin "$RELEASE_BRANCH"


# sed -i "s/quay.io\/devtron\/$APP_DOCKER_REPO:.*/quay.io\/devtron\/$APP_DOCKER_REPO:$DOCKER_IMAGE_TAG\"/" charts/devtron/$HYPERION_APP_MANIFEST

echo "=================Additional check for orchestrator image change====================="

if [[ $APP_DOCKER_REPO == "devtron" ]]
 then
   sed -i "s/quay.io\/devtron\/hyperion:.*/quay.io\/devtron\/hyperion:$DOCKER_IMAGE_TAG\"/" charts/devtron/$HYPERION_APP_MANIFEST
   echo "hyperion image tag change for orchestrator"
 else 
   sed -i "s/quay.io\/devtron\/$APP_DOCKER_REPO:.*/quay.io\/devtron\/$APP_DOCKER_REPO:$DOCKER_IMAGE_TAG\"/" charts/devtron/$HYPERION_APP_MANIFEST
   echo "$APP_DOCKER_REPO Microservice image tag change for "
fi

echo "=================End Additional check for orchestrator image change====================="

echo "######################################"

if [[ $DEV_RELEASE == $RELEASE_VERSION ]]
  then
    #RELEASE_VERSION=$(../bin/gh release list -L 1 -R $REPO | awk '{print $1}')
    HYP_RELEASE_VERSION=$(echo ${DEV_RELEASE} | awk -F. -v OFS=. '{$NF++;print}')
    echo "NEXTVERSION from inside loop: $HYP_RELEASE_VERSION"
    sed -i "s/$DEV_RELEASE/$HYP_RELEASE_VERSION/" $VERSION_FILE_HYPERION
  else
    HYP_RELEASE_VERSION=$DEV_RELEASE
    echo "NEXTVERSION from inside ESLE: $HYP_RELEASE_VERSION"
fi


echo '===============================Chart Version Change================================='

#Version change in Chart.yaml
wget https://raw.githubusercontent.com/gunish-dt/hyperionRelease/main/charts/devtron/Chart.yaml -O Chart.yaml
CHART_DEV_RELEASE=$(sed -nre '13s/^[^0-9]*(([0-9]+\.)*[0-9]+).*/\1/p' Chart.yaml)
echo $CHART_DEV_RELEASE

CHART_NEXT_RELEASE=$(echo ${CHART_DEV_RELEASE} | awk -F. -v OFS=. '{$NF++;print}')

echo $CHART_NEXT_RELEASE

sed -i "s/$CHART_DEV_RELEASE/$CHART_NEXT_RELEASE/" $VERSION_FILE_CHART

rm Chart.yaml



echo "====================If else to check microservice for migration changes================="

if [[ $APP_DOCKER_REPO == "devtron" ]]
  then
# ========== Updating the Migration script with latest commit hash ==========
    sed -i "$HYPERION_DEVTRON_MIGRATOR_LINE s/GIT_HASH.*/GIT_HASH: \"$BUILD_COMMIT\"/" charts/devtron/$HYPERION_APP_MANIFEST
    sed -i "$HYPERION_CASBIN_MIGRATOR_LINE s/GIT_HASH.*/GIT_HASH: \"$BUILD_COMMIT\"/" charts/devtron/$HYPERION_APP_MANIFEST
  else
    echo "No Migration change in values.yaml file for hyperion"
fi
  
git commit -am "Updated latest image of $APP_DOCKER_REPO in Values.yaml file"
git push -f https://$GIT_USERNAME:$GITHUB_TOKENS@$HYPERION_GIT_REPO --all
#Creating Release ######################
#RELEASE_RESPONSE=$(../bin/gh release create $NEXT_RELEASE_VERSION --target $RELEASE_BRANCH -R $REPO)
#echo "FINAL RELEASE RESPONSE: $RELEASE_RESPONSE"
#Creating PR into main branch
HYPE_PR_RESPONSE=$(../bin/gh pr create --title "RELEASE: PR for $NEXT_RELEASE_VERSION" --body "Updates in $APP_DOCKER_REPO micro-service" --base $GIT_BRANCH --head $RELEASE_BRANCH --repo $HYPERION_REPO)
echo "FINAL PR RESPONSE: $HYPE_PR_RESPONSE"