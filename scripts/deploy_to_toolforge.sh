#!/usr/bin/env bash

set -e

user=${1-$USER}

npm install
npm run build
chmod -R +w dist
chgrp -R tools.dp-pageviews dist
scp -r dist $user@login.toolforge.org:/data/project/dp-pageviews/dist
ssh $user@login.toolforge.org "
  set -ex
  become dp-pageviews bash -xc \"
    take dist &&
    set -e &&
    rm -rf public_html.bak &&
    mv public_html public_html.bak &&
    mv dist public_html &&
    webservice stop &&
    webservice start
  \"
"
