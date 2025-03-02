#!/bin/bash

set -Eeuo pipefail

# TODO: move all mkdir -p ?
mkdir -p /data/config/auto/scripts/
# mount scripts individually
find "${ROOT}/scripts/" -maxdepth 1 -type l -delete
cp -vrfTs /data/config/auto/scripts/ "${ROOT}/scripts/"

# Set up config file
python /docker/config.py /data/config/auto/config.json

if [ ! -f /data/config/auto/ui-config.json ]; then
  echo '{}' >/data/config/auto/ui-config.json
fi

if [ ! -f /data/config/auto/styles.csv ]; then
  touch /data/config/auto/styles.csv
fi

# copy models from original models folder
mkdir -p /data/models/VAE-approx/ /data/models/karlo/

rsync -a --info=NAME ${ROOT}/models/VAE-approx/ /data/models/VAE-approx/
rsync -a --info=NAME ${ROOT}/models/karlo/ /data/models/karlo/

declare -A MOUNTS

MOUNTS["/root/.cache"]="/data/.cache"

# # main
# MOUNTS["${ROOT}/models/Stable-diffusion"]="/data/StableDiffusion"
# MOUNTS["${ROOT}/models/VAE"]="/data/VAE"
# MOUNTS["${ROOT}/models/Codeformer"]="/data/Codeformer"
# MOUNTS["${ROOT}/models/GFPGAN"]="/data/GFPGAN"
# MOUNTS["${ROOT}/models/ESRGAN"]="/data/ESRGAN"
# MOUNTS["${ROOT}/models/BSRGAN"]="/data/BSRGAN"
# MOUNTS["${ROOT}/models/RealESRGAN"]="/data/RealESRGAN"
# MOUNTS["${ROOT}/models/SwinIR"]="/data/SwinIR"
# MOUNTS["${ROOT}/models/ScuNET"]="/data/ScuNET"
# MOUNTS["${ROOT}/models/LDSR"]="/data/LDSR"
# MOUNTS["${ROOT}/models/hypernetworks"]="/data/Hypernetworks"
# MOUNTS["${ROOT}/models/torch_deepdanbooru"]="/data/Deepdanbooru"
# MOUNTS["${ROOT}/models/BLIP"]="/data/BLIP"
# MOUNTS["${ROOT}/models/midas"]="/data/MiDaS"
# MOUNTS["${ROOT}/models/Lora"]="/data/Lora"
# MOUNTS["${ROOT}/models/LyCORIS"]="/data/LyCORIS"
# MOUNTS["${ROOT}/models/ControlNet"]="/data/ControlNet"
# MOUNTS["${ROOT}/models/openpose"]="/data/openpose"
# MOUNTS["${ROOT}/models/ModelScope"]="/data/ModelScope"

# MOUNTS["${ROOT}/embeddings"]="/data/embeddings"
# MOUNTS["${ROOT}/config.json"]="/data/config/auto/config.json"
# MOUNTS["${ROOT}/ui-config.json"]="/data/config/auto/ui-config.json"
# MOUNTS["${ROOT}/styles.csv"]="/data/config/auto/styles.csv"
# MOUNTS["${ROOT}/extensions"]="/data/config/auto/extensions"

# extra hacks
MOUNTS["${ROOT}/repositories/CodeFormer/weights/facelib"]="/data/.cache"

for to_path in "${!MOUNTS[@]}"; do
  set -Eeuo pipefail
  from_path="${MOUNTS[${to_path}]}"
  rm -rf "${to_path}"
  if [ ! -f "$from_path" ]; then
    mkdir -vp "$from_path"
  fi
  mkdir -vp "$(dirname "${to_path}")"
  ln -sT "${from_path}" "${to_path}"
  echo Mounted $(basename "${from_path}")
done

echo "Installing extension dependencies (if any)"

# because we build our container as root:
chown -R root ~/.cache/
chmod 766 ~/.cache/

shopt -s nullglob
# For install.py, please refer to https://github.com/AUTOMATIC1111/stable-diffusion-webui/wiki/Developing-extensions#installpy
list=(./extensions/*/install.py)
for installscript in "${list[@]}"; do
  PYTHONPATH=${ROOT} python "$installscript"
done

if [ -f "/data/config/auto/startup.sh" ]; then
  pushd ${ROOT}
  echo "Running startup script"
  . /data/config/auto/startup.sh
  popd
fi

exec "$@"
