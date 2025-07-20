git clone git@github.com:anpa8480/FRDM_imx93.git

```console
docker build --build-arg USERNAME=$(whoami) --build-arg USER_UID=$(id -u) --build-arg USER_GID=$(id -g) -t frdm-ubuntu:latest .
```
```console
docker run --security-opt seccomp=unconfined -it --rm -v $PWD:/home/$(whoami)/frdm-ubuntu --name frdm-ubuntu_container frdm-ubuntu:latest
```

install SDK which I created using https://www.nxp.com/document/guide/getting-started-with-frdm-imx93:GS-FRDM-IMX93?section=build-and-run

```console
./sdk_install/fsl-imx-xwayland-glibc-x86_64-imx-image-full-armv8a-imx93frdm-toolchain-6.6-scarthgap.sh
```

```console
cd custom
./build-uboot.sh
```
