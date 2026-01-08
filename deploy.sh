#!/bin/bash
cd cleaning_report_app
fvm flutter build web --release --base-href "/cleaning-report/"
cd ..
rm -rf docs/*
cp -r cleaning_report_app/build/web/* docs/
touch docs/.nojekyll
git add .
git commit -m "Deploy: $(date)"
git push
