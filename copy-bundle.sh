adb shell touch /data/local/tmp/bundle.json
adb shell run-as $1 cp /data/data/$1/files/bundle.json /data/local/tmp/
adb pull /data/local/tmp/bundle.json ./src/assets/bundle.json