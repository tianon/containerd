#!/usr/bin/env bash

PROJECT=github.com/docker/containerd

# Downloads dependencies into vendor/ directory
mkdir -p vendor/src

if ! go list "$PROJECT/containerd" &> /dev/null; then
	rm -rf .gopath
	mkdir -p ".gopath/src/$(dirname "$PROJECT")"
	ln -sf ../../../.. ".gopath/src/$PROJECT"
	export GOPATH="$PWD/.gopath"
fi
export GOPATH="$GOPATH:$PWD/vendor"

clone() {
	local vcs="$1"
	local pkg="$2"
	local rev="$3"
	local url="$4"

	: ${url:=https://$pkg}
	local target="vendor/src/$pkg"

	echo -n "$pkg @ $rev: "

	if [ -d "$target" ]; then
		echo -n 'rm old, '
		rm -rf "$target"
	fi

	echo -n 'clone, '
	case "$vcs" in
		git)
			git clone --quiet --no-checkout "$url" "$target"
			( cd "$target" && git checkout --quiet "$rev" && git reset --quiet --hard "$rev" )
			;;
		hg)
			hg clone --quiet --updaterev "$rev" "$url" "$target"
			;;
	esac

	echo -n 'rm VCS, '
	( cd "$target" && rm -rf .{git,hg} )

	echo -n 'rm vendor, '
	( cd "$target" && rm -rf vendor Godeps/_workspace )

	echo done
}

clean() {
	echo

	# "main" packages
	local packages=(
		"$PROJECT/containerd"
		"$PROJECT/ctr"
		"$PROJECT/hack/benchmark.go"
	)
	local tags='runc libcontainer seccomp'
	local platforms=(linux/amd64 linux/386 linux/arm windows/amd64 windows/385 darwin/amd64)

	echo -n 'collecting import graph, '
	local IFS=$'\n'
	local imports=( $(
		for platform in $platforms; do
			export GOOS="${platform%/*}";
			export GOARCH="${platform##*/}";
			go list -e -tags="$tags" -f '{{join .Deps "\n"}}' "${packages[@]}"
			go list -e -tags="$tags" -f '{{join .TestImports "\n"}}' "${packages[@]}"
		done | grep -vE "^${PROJECT}" | sort -u
	) )
	imports=( $(go list -e -f '{{if not .Standard}}{{.ImportPath}}{{end}}' "${imports[@]}") )
	unset IFS

	echo -n 'pruning unused packages, '
	findArgs=()
	for import in "${imports[@]}"; do
		[ "${#findArgs[@]}" -eq 0 ] || findArgs+=( -or )
		findArgs+=( -path "vendor/src/$import" )
	done
	local IFS=$'\n'
	local prune=( $(find vendor/src -depth -type d -not '(' "${findArgs[@]}" ')') )
	unset IFS
	for dir in "${prune[@]}"; do
		find "$dir" -maxdepth 1 -not -type d -not -name 'LICENSE*' -not -name 'COPYING*' -exec rm -v -f '{}' ';'
		rmdir "$dir" 2>/dev/null || true
	done

	echo -n 'pruning unused files, '
	find vendor/src -type f -name '*_test.go' -exec rm -v '{}' ';'

	echo done
}
