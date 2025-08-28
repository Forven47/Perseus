#!/bin/bash
# Download apkeep
get_artifact_download_url () {
    # Usage: get_download_url <repo_name> <artifact_name> <file_type>
    local api_url="https://api.github.com/repos/$1/releases/latest"
    local result=$(curl $api_url | jq ".assets[] | select(.name | contains(\"$2\") and contains(\"$3\") and (contains(\".sig\") | not)) | .browser_download_url")
    echo ${result:1:-1}
}

# Artifacts associative array aka dictionary
declare -A artifacts

artifacts["apkeep"]="EFForg/apkeep apkeep-x86_64-unknown-linux-gnu"
artifacts["apktool.jar"]="iBotPeaches/Apktool apktool .jar"

# Fetch all the dependencies
for artifact in "${!artifacts[@]}"; do
    if [ ! -f $artifact ]; then
        echo "Downloading $artifact"
        curl -L -o $artifact $(get_artifact_download_url ${artifacts[$artifact]})
    fi
done

chmod +x apkeep

: <<FF
# Download Azur Lane
if [ ! -f "com.bilibili.AzurLane.apk" ]; then
    echo "Get Azur Lane apk"

    # eg: wget "your download link" -O "your packge name.apk" -q
    #if you want to patch .xapk, change the suffix here to wget "your download link" -O "your packge name.xapk" -q
    #wget https://pkg.biligame.com/games/blhx_9.5.11_0427_1_20250506_095207_d4e3f.apk -O com.bilibili.AzurLane.apk -q
    wget https://pkg.biligame.com/games/blhx_9.6.11_0814_1_20250819_110937_2a0c3.apk -O com.bilibili.AzurLane.apk -q
    echo "apk downloaded !"
    
    # if you can only download .xapk file uncomment 2 lines below. (delete the '#')
    #unzip -o com.YoStarJP.AzurLane.xapk -d AzurLane
    #cp AzurLane/com.YoStarJP.AzurLane.apk .
fi
FF

echo "Get Azur Lane apk"
7z x com.bilibili.AzurLane.zip
echo "apk downloaded !"

: <<FF
# Download Perseus
if [ ! -d "Perseus" ]; then
    echo "Downloading Perseus"
    git clone https://github.com/Egoistically/Perseus
fi
FF

# Download JMBQ
if [ ! -d "azurlane" ]; then
    echo "download JMBQ"
    git clone https://github.com/feathers-l/azurlane
fi

echo "Decompile Azur Lane apk"
#java -jar apktool.jar -q -f d com.bilibili.AzurLane.apk
java -jar apktool.jar d -f com.bilibili.AzurLane.apk

echo "Copy JMBQ libs"
cp -r Perseus/. com.bilibili.AzurLane/lib/

: <<FF
echo "Patching Azur Lane with Perseus"
oncreate=$(grep -n -m 1 'onCreate' com.bilibili.AzurLane/smali_classes2/com/unity3d/player/UnityPlayerActivity.smali | sed  's/[0-9]*\:\(.*\)/\1/')
sed -ir "s#\($oncreate\)#.method private static native init(Landroid/content/Context;)V\n.end method\n\n\1#" com.bilibili.AzurLane/smali_classes2/com/unity3d/player/UnityPlayerActivity.smali
sed -ir "s#\($oncreate\)#\1\n    const-string v0, \"Perseus\"\n\n\    invoke-static {v0}, Ljava/lang/System;->loadLibrary(Ljava/lang/String;)V\n\n    invoke-static {p0}, Lcom/unity3d/player/UnityPlayerActivity;->init(Landroid/content/Context;)V\n#" com.bilibili.AzurLane/smali_classes2/com/unity3d/player/UnityPlayerActivity.smali
FF

echo "Patching Azur Lane with JMBQ"
oncreate=$(grep -n -m 1 'onCreate'  com.bilibili.AzurLane/smali_classes3/com/unity3d/player/UnityPlayerActivity.smali | sed  's/[0-9]*\:\(.*\)/\1/')
sed -ir "N; s#\($oncreate\n    .locals 2\)#\1\n    const-string v0, \"JMBQ\"\n\n    invoke-static {v0}, Ljava/lang/System;->loadLibrary(Ljava/lang/String;)V\n#" com.bilibili.AzurLane/smali_classes3/com/unity3d/player/UnityPlayerActivity.smali

echo "Build Patched Azur Lane apk"
#java -jar apktool.jar -q -f b com.bilibili.AzurLane -o build/com.bilibili.AzurLane.patched.apk
java -jar apktool.jar b -f com.bilibili.AzurLane -o build/com.bilibili.AzurLane.patched.apk

echo "Set Github Release version"
s=($(./apkeep -a com.bilibili.AzurLane -l))
echo "PERSEUS_VERSION=$(echo ${s[-1]})" >> $GITHUB_ENV
