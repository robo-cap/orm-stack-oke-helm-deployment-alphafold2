
imagePullSecrets:
- name: ${nvcr_secret}

model:
  ngcAPISecret: ${ngcapi_secret}

env:
- name: NIM_CACHE_PATH
  value: "/cache-on-fss"

image:
  repository: ${nim_image_repository}
  tag: ${nim_image_tag}

resources:
  requests:
    nvidia.com/gpu: 1
  limits:
    nvidia.com/gpu: 1

extraVolumes:
  model-cache:
    persistentVolumeClaim:
      claimName: fss-pvc

extraVolumeMounts:
  model-cache:
    mountPath: /cache-on-fss

initContainers:
  extraInit:
  - name: change-permissions
    image: busybox
    command: ["sh", "-c", "chmod -R 777 /cache-on-fss || echo done"]
    securityContext:
      runAsUser: 0 
    volumeMounts:
    - name: model-cache
      mountPath: /cache-on-fss

startupProbe:
  failureThreshold: 960
  periodSeconds: 30