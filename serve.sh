#!/bin/bash
nix-shell -p hexo-cli nodejs --command "rm -rf node_modules && npm install --force; hexo serve"