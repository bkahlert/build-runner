# bkahlert/build-runner [![Build Status](https://img.shields.io/github/workflow/status/bkahlert/build-runner/build?label=Build&logo=github&logoColor=fff)](https://github.com/bkahlert/build-runner/actions/workflows/build-and-publish.yml) [![Repository Size](https://img.shields.io/github/repo-size/bkahlert/build-runner?color=01818F&label=Repo%20Size&logo=Git&logoColor=fff)](https://github.com/bkahlert/build-runner) [![Repository Size](https://img.shields.io/github/license/bkahlert/build-runner?color=29ABE2&label=License&logo=data%3Aimage%2Fsvg%2Bxml%3Bbase64%2CPHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCA1OTAgNTkwIiAgeG1sbnM6dj0iaHR0cHM6Ly92ZWN0YS5pby9uYW5vIj48cGF0aCBkPSJNMzI4LjcgMzk1LjhjNDAuMy0xNSA2MS40LTQzLjggNjEuNC05My40UzM0OC4zIDIwOSAyOTYgMjA4LjljLTU1LjEtLjEtOTYuOCA0My42LTk2LjEgOTMuNXMyNC40IDgzIDYyLjQgOTQuOUwxOTUgNTYzQzEwNC44IDUzOS43IDEzLjIgNDMzLjMgMTMuMiAzMDIuNCAxMy4yIDE0Ny4zIDEzNy44IDIxLjUgMjk0IDIxLjVzMjgyLjggMTI1LjcgMjgyLjggMjgwLjhjMCAxMzMtOTAuOCAyMzcuOS0xODIuOSAyNjEuMWwtNjUuMi0xNjcuNnoiIGZpbGw9IiNmZmYiIHN0cm9rZT0iI2ZmZiIgc3Ryb2tlLXdpZHRoPSIxOS4yMTIiIHN0cm9rZS1saW5lam9pbj0icm91bmQiLz48L3N2Zz4%3D)](https://github.com/bkahlert/build-runner/blob/master/LICENSE)

* Ubuntu 20.04 based Docker Image  
  * Docker CLI
  * OpenJDK 11
  * SSH access
  * rsync
* Compatible with IntelliJ IDEA [run targets feature](https://www.jetbrains.com/help/idea/run-targets.html#target-types)

## Build locally

```shell
git clone https://github.com/bkahlert/build-runner.git
cd build-runner

# Build image and output to docker (default)
docker buildx bake

# Build multi-platform image
docker buildx bake image-all
```

## Image

* [Docker Hub](https://hub.docker.com/r/bkahlert/build-runner/) `bkahlert/build-runner`
* [GitHub Container Registry](https://github.com/users/bkahlert/packages/container/package/build-runner) `ghcr.io/bkahlert/build-runner`

Following platforms for this image are available:
* linux/amd64
* linux/arm64/v8


## Usage

### Run as an application

If you pass arguments to the container, they will be treated like
a regular command line. The container will run the command line and terminate.

```shell
docker run --rm -it \
  -v "$(pwd):$(pwd)" \
  -w "$(pwd)" \
  bkahlert/build-runner:edge \
  javac --version
```

### Run as a service / SSH server 

Starting the container without any arguments will launch an
SSH server that will listen for connections.

```shell
docker run --rm \
  -v "$(pwd):$(pwd)" \
  -w "$(pwd)" \
  -p 2022:2022 \
  bkahlert/build-runner:edge

# connect
ssh -p 2022 runner@localhost
```


## Configuration

The build runner can be configured using the following options of which each exists as both—build argument and environment variable.  
You should go for build arguments if you want to set custom defaults you don't intend to change (often). Environment variables will overrule any existing configuration on each container start. 

* `TZ` Timezone the container runs in (default: `UTC`)
* `PUID` User ID of the `runner` user (default: `1000`) 
* `PGID` Group ID of the `runner` group (default: `1000`)
* `AUTHORIZED_KEYS` Public key(s) that can be used to log in via SSH as `runner`
* `PASSWORD` Password of `runner` (default: `runner`)

> 🔐 Specifying authorized key(s) will automatically disable password-based authentication. An eventually also configured password will be ignored.  
> Setting authorized key(s) to an empty string, will re-enable the password-based authentication with either the provided or otherwise a randomly generated password.

```shell
# Build single image with build argument AUTHORIZED_KEYS
docker buildx bake --build-arg AUTHORIZED_KEYS="$(cat ~/.ssh/id_rsa.pub)"

# Build multi-platform image with build argument AUTHORIZED_KEYS
docker buildx bake image-all --build-arg AUTHORIZED_KEYS="$(cat ~/.ssh/id_rsa.pub)"

# Start container with environment variable AUTHORIZED_KEYS
docker run --rm \
  -e AUTHORIZED_KEYS="$(cat ~/.ssh/id_rsa.pub)" \
  -v "$(pwd):$(pwd)" \
  -w "$(pwd)" \
  -p 2022:2022 \
  -p 2022:2022 \
  bkahlert/build-runner:edge
```


## Testing

```shell
git clone https://github.com/bkahlert/build-runner.git
cd build-runner

# Use Bats wrapper to run tests
chmod +x ./batsw
DOCKER_BAKE="--set *.tags=test" \
  ./batsw --env BUILD_TAG=test test
```

`batsw` is a wrapper for the Bash testing framework [Bats](https://github.com/bats-core/bats-core).   
It builds a Docker image on-the-fly containing Bats incl. several libraries and runs all tests
contained in the specified directory.

> 💡 To accelerate testing, the Bats Wrapper checks if any test is prefixed with a capital X and if so, only runs those tests.


## Contributing

Want to contribute? Awesome! The most basic way to show your support is to star the project, or to raise issues. You
can also support this project by making
a [Paypal donation](https://www.paypal.me/bkahlert) to ensure this journey continues indefinitely!

Thanks again for your support, it is much appreciated! :pray:


## License

MIT. See [LICENSE](LICENSE) for more details.
