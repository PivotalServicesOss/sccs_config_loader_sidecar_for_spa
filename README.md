# Configuration loader sidecar application

- This app loads the configuration for a static file application (Angular) from a spring cloud config server.

> Note: This app can be modified to server any type of static file applications as well

## Getting started

- Compile and build image of this application using `./build.bat ci`
- Push the image of this application using `./build.bat pi`
- Now that the image is in your registry, you can use this app as a side-car to your angular file app. Below are the configuration/env-variable required by the side-car app to perform its job

    1. `APPLICATION_NAME` - name of the application, especially the name of the config file in the git repo `applicationname-profile.yaml`
    1. `CONFIGSERVER_URI` - full uri of spring cloud config server instane
    1. `CONFIG_FOLDER_PATH` - folder name in the mount where the config file(s) to be created
    1. `CONFIG_FILE_NAME` - file name including extension in the `CONFIG_FOLDER_PATH`
    1. `ENABLE_DIAGNOSTICS_ENDPOINTS` - enable or disable endpoints that exposes diagnostics information

> Environment name or profile name should be lower case. e.g. file name should look like `appname-development.yaml`. The same case should go into `ASPNETCORE_ENVIRONMENT` environment variable.

- A sample `deployment.yaml` file looks like below

    ```yaml
    ---
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: angular-app
      labels:
        app: angular-app
    spec:
      replicas: 1
      selector:
        matchLabels:
          app: angular-app
      template:
        metadata:
          labels:
            app: angular-app
        spec:
          containers:
          - name: angular-app
            image: angular-app-image:latest
            resources:
              requests:
                memory: "64Mi"
                cpu: "250m"
              limits:
                memory: "128Mi"
                cpu: "500m"
            imagePullPolicy: Never
            env:
            - name: PORT
              value: "8080"
            ports:
            - containerPort: 8080
            volumeMounts:
            - name: config-volume
              mountPath: /workspace/dist/assets/config
          - name: configloader-sidecar
            image: index.docker.io/<repo_name>/configloader-sidecar-app:latest
            resources:
              requests:
                memory: "64Mi"
                cpu: "250m"
              limits:
                memory: "512Mi"
                cpu: "500m"
            env:
            - name: ASPNETCORE_ENVIRONMENT
              value: "development"
            - name: APPLICATION_NAME
              value: "ui"
            - name: CONFIGSERVER_URI
              value: "http://localhost:8888/"
            - name: CONFIG_FOLDER_PATH
              value: "/workspace/dist/assets/config/"
            - name: CONFIG_FILE_NAME
              value: "config.json"
            - name: ENABLE_DIAGNOSTICS_ENDPOINTS
              value: "true"
            - name: PORT
              value: "8081"
            volumeMounts:
            - name: config-volume
              mountPath: /workspace/dist/assets/config
          volumes:
          - name: config-volume
            emptyDir: {}
    ---
    ```
