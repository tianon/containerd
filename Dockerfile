FROM debian:jessie

RUN apt-get update && apt-get install -y \
	build-essential \
	ca-certificates \
	curl \
	git \
	make \
	--no-install-recommends \
	&& rm -rf /var/lib/apt/lists/*

# Install Go
ENV GO_VERSION 1.5.2
RUN curl -sSL  "https://storage.googleapis.com/golang/go${GO_VERSION}.linux-amd64.tar.gz" | tar -v -C /usr/local -xz
ENV PATH /go/bin:/usr/local/go/bin:$PATH
ENV GOPATH /go:/go/src/github.com/docker/containerd/vendor

# install golint/vet
RUN go get github.com/golang/lint/golint \
	&& go get golang.org/x/tools/cmd/vet

COPY . /go/src/github.com/docker/containerd

# get deps, until they are in vendor
# TODO: remomve this when there is a dep tool
RUN go get -d -v github.com/docker/containerd/ctr \
	&& go get -d -v github.com/docker/containerd/containerd

WORKDIR /go/src/github.com/docker/containerd
