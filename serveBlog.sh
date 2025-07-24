podman run --rm -p 62000:4000 -v $(pwd):/site:Z -v $(pwd)/.bundlecache:/usr/local/bundle:Z ghcr.io/deb4sh/docker-jekyll-serve:0.0.1-1753097641
