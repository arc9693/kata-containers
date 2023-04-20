package coco_policy

import future.keywords.in
import future.keywords.every

import input

######################################################################
# Default values:
#
# - true for requests that are allowed by default.
# - false for requests that have additional policy rules, defined below.
# - Requests that are not listed here get rejected by default.

# More detailed policy rules are below.
default CreateContainerRequest := false

# Requests that are always allowed.
default CreateSandboxRequest := true
default DestroySandboxRequest := true
default GetOOMEventRequest := true
default GuestDetailsRequest := true
default OnlineCPUMemRequest := true
default PullImageRequest := true
default ReadStreamRequest := true
default RemoveContainerRequest := true
default SetPolicyRequest := true
default SignalProcessRequest := true
default StartContainerRequest := true
default StatsContainerRequest := true
default TtyWinResizeRequest := true
default UpdateInterfaceRequest := true
default UpdateRoutesRequest := true
default WaitProcessRequest := true
default WriteStreamRequest := true


######################################################################
CreateContainerRequest {
    policy_container := policy_data.containers[_]
    policy_oci := policy_container.oci
    policy_storages := policy_container.storages

    input_oci := input.oci
    input_storages := input.storages

    print("CreateContainerRequest", "policy_oci.ociVersion")
    policy_oci.ociVersion     == input_oci.ociVersion

    print("CreateContainerRequest", "policy_oci.root.readonly")
    policy_oci.root.readonly  == input_oci.root.readonly

    print("CreateContainerRequest", "allow_by_annotations")
    allow_by_annotations(policy_oci, input_oci, policy_storages, input_storages)

    print("CreateContainerRequest", "allow_linux")
    allow_linux(policy_oci, input_oci)

    print("CreateContainerRequest", "success")
}

######################################################################
# Get "io.kubernetes.cri.sandbox-name", and correlate its value with other
# annotations and process fields.

allow_by_annotations(policy_oci, input_oci, policy_storages, input_storages) {
    print("allow_by_annotations", "no policy io.kubernetes.cri.sandbox-name")
    not policy_oci.annotations["io.kubernetes.cri.sandbox-name"]

    input_sandbox_name := input_oci.annotations["io.kubernetes.cri.sandbox-name"]

    print("allow_by_annotations", "allow_by_sandbox_name")
    allow_by_sandbox_name(policy_oci, input_oci, policy_storages, input_storages, input_sandbox_name)

    print("allow_by_annotations", "success")
}
allow_by_annotations(policy_oci, input_oci, policy_storages, input_storages) {
    print("allow_by_annotations", "io.kubernetes.cri.sandbox-name")
    policy_sandbox_name := policy_oci.annotations["io.kubernetes.cri.sandbox-name"]
    input_sandbox_name := input_oci.annotations["io.kubernetes.cri.sandbox-name"]
    policy_sandbox_name == input_sandbox_name

    print("allow_by_annotations", "allow_by_sandbox_name")
    allow_by_sandbox_name(policy_oci, input_oci, policy_storages, input_storages, input_sandbox_name)

    print("allow_by_annotations", "success")
}

allow_by_sandbox_name(policy_oci, input_oci, policy_storages, input_storages, sandbox_name) {
    print("allow_by_sandbox_name", "allow_by_container_types")
    allow_by_container_types(policy_oci, input_oci, sandbox_name)

    print("allow_by_sandbox_name", "allow_by_bundle_or_sandbox_id")
    allow_by_bundle_or_sandbox_id(policy_oci, input_oci, policy_storages, input_storages)

    print("allow_by_sandbox_name", "allow_sandbox_namespace")
    allow_sandbox_namespace(policy_oci, input_oci)

    print("allow_by_sandbox_name", "allow_process")
    allow_process(policy_oci, input_oci, sandbox_name)

    print("allow_by_sandbox_name", "success")
}

######################################################################
# - Check that the "io.kubernetes.cri.container-type" and
#   "io.katacontainers.pkg.oci.container_type" annotations
#   designate the expected type - either a "sandbox" or a
#   "container" type.
#
# - Then, validate other annotations based on the actual
#   "sandbox" or "container" value from the input container.

allow_by_container_types(policy_oci, input_oci, sandbox_name) {
    policy_cri_type := policy_oci.annotations["io.kubernetes.cri.container-type"]
    input_cri_type := input_oci.annotations["io.kubernetes.cri.container-type"]
    policy_cri_type == input_cri_type

    print("allow_by_container_types", "allow_by_container_type")
    allow_by_container_type(input_cri_type, policy_oci, input_oci, sandbox_name)

    print("allow_by_container_types", "success")
}

# Rules applicable to the "sandbox" container type
allow_by_container_type(input_cri_type, policy_oci, input_oci, sandbox_name) {
    input_cri_type == "sandbox"
    print("allow_by_container_type", "sandbox")

    # TODO: Enable hostname validation after researching how that works
    #       for pods including multiple containers.
    #policy_oci.hostname == input_oci.hostname

    input_kata_type := input_oci.annotations["io.katacontainers.pkg.oci.container_type"]
    input_kata_type == "pod_sandbox"

    allow_sandbox_container_name(policy_oci, input_oci)
    allow_sandbox_image_name(policy_oci, input_oci)
    allow_sandbox_net_namespace(policy_oci, input_oci)
    allow_sandbox_log_directory(policy_oci, input_oci, sandbox_name)

    print("allow_by_container_type", "success")
}

# Rules applicable to the "container" container type
allow_by_container_type(input_cri_type, policy_oci, input_oci, sandbox_name) {
    input_cri_type == "container"
    print("allow_by_container_type", "container")

    input_kata_type := input_oci.annotations["io.katacontainers.pkg.oci.container_type"]
    print("allow_by_container_type", input_kata_type)
    input_kata_type == "pod_container"

    print("allow_by_container_type", "allow_container_name")
    allow_container_name(policy_oci, input_oci)

    print("allow_by_container_type", "allow_image_name")
    allow_image_name(policy_oci, input_oci)

    print("allow_by_container_type", "allow_net_namespace")
    allow_net_namespace(policy_oci, input_oci)

    print("allow_by_container_type", "allow_log_directory")
    allow_log_directory(policy_oci, input_oci)

    print("allow_by_container_type", "success")
}

######################################################################
# "io.kubernetes.cri.image-name" annotation

allow_sandbox_image_name(policy_oci, input_oci) {
    container_annotation_missing(policy_oci, input_oci, "io.kubernetes.cri.image-name")
}

allow_image_name(policy_oci, input_oci) {
    # TODO: compare properly "docker.io/library/hello-world:latest" with  "hello-world"
    allow_container_annotation(policy_oci, input_oci, "io.kubernetes.cri.image-name")
}

######################################################################
# "io.kubernetes.cri.container-name" annotation

allow_sandbox_container_name(policy_oci, input_oci) {
    container_annotation_missing(policy_oci, input_oci, "io.kubernetes.cri.container-name")
}

allow_container_name(policy_oci, input_oci) {
    allow_container_annotation(policy_oci, input_oci, "io.kubernetes.cri.container-name")
}

######################################################################
# Annotions required for "container" type, and not allowed for "sandbox" type.

container_annotation_missing(policy_oci, input_oci, annotation_key) {
    not policy_oci.annotations[annotation_key]
    not input_oci.annotations[annotation_key]
}

allow_container_annotation(policy_oci, input_oci, annotation_key) {
    policy_value := policy_oci.annotations[annotation_key]
    print("allow_container_annotation", policy_value)

    input_value := input_oci.annotations[annotation_key]
    print("allow_container_annotation", input_value)

    policy_value == input_value
    print("allow_container_annotation", "success")
}

######################################################################
# "nerdctl/network-namespace" annotation

allow_sandbox_net_namespace(policy_oci, input_oci) {
    policy_namespace := policy_oci.annotations["nerdctl/network-namespace"]
    input_namespace := input_oci.annotations["nerdctl/network-namespace"]

    regex.match(policy_namespace, input_namespace)
}

allow_net_namespace(policy_oci, input_oci) {
    not policy_oci.annotations["nerdctl/network-namespace"]
    not input_oci.annotations["nerdctl/network-namespace"]
}

######################################################################
# "io.kubernetes.cri.sandbox-log-directory" annotation

allow_sandbox_log_directory(policy_oci, input_oci, sandbox_name) {
    policy_log_directory := policy_oci.annotations["io.kubernetes.cri.sandbox-log-directory"]
    directory_regex := replace(policy_log_directory, "$(sandbox-name)", sandbox_name)

    input_log_directory := input_oci.annotations["io.kubernetes.cri.sandbox-log-directory"]
    regex.match(directory_regex, input_log_directory)
}

allow_log_directory(policy_oci, input_oci) {
    not policy_oci.annotations["io.kubernetes.cri.sandbox-log-directory"]
    not input_oci.annotations["io.kubernetes.cri.sandbox-log-directory"]
}

######################################################################
# "io.kubernetes.cri.sandbox-namespace" annotation

allow_sandbox_namespace(policy_oci, input_oci) {
    policy_namespace := policy_oci.annotations["io.kubernetes.cri.sandbox-namespace"]
    input_namespace := input_oci.annotations["io.kubernetes.cri.sandbox-namespace"]

    policy_namespace == input_namespace
}

######################################################################
# Validate the linux fields from config.json.

allow_linux(policy_oci, input_oci) {
    policy_oci.linux.namespaces     == input_oci.linux.namespaces

    allow_array(policy_oci.linux.maskedPaths, input_oci.linux.maskedPaths)
    allow_array(policy_oci.linux.readonlyPaths, input_oci.linux.readonlyPaths)
}

allow_array(policy_array, input_array) {
    policy_element := policy_array[_]
    input_element := input_array[_]

    policy_element == input_element
}

######################################################################
# Get the input:
#
# - bundle_id from "io.katacontainers.pkg.oci.bundle_path"
# - sandbox_id from "io.kubernetes.cri.sandbox-id"
#
# and check their consistency with other rules.

allow_by_bundle_or_sandbox_id(policy_oci, input_oci, policy_storages, input_storages) {
    bundle_path := input_oci.annotations["io.katacontainers.pkg.oci.bundle_path"]
    bundle_id := replace(bundle_path, "/run/containerd/io.containerd.runtime.v2.task/k8s.io/", "")

    policy_sandbox_regex := policy_oci.annotations["io.kubernetes.cri.sandbox-id"]
    sandbox_id := input_oci.annotations["io.kubernetes.cri.sandbox-id"]

    print("allow_by_bundle_or_sandbox_id", "regex.match")
    regex.match(policy_sandbox_regex, sandbox_id)

    print("allow_by_bundle_or_sandbox_id", "allow_root_path")
    allow_root_path(policy_oci, input_oci, bundle_id)

    every input_mount in input.oci.mounts {
        print("allow_by_bundle_or_sandbox_id", "allow_mount")
        allow_mount(policy_oci, input_mount, bundle_id, sandbox_id)
    }

    print("allow_by_bundle_or_sandbox_id", "allow_storages")
    allow_storages(policy_storages, input_storages, sandbox_id)

    print("allow_by_bundle_or_sandbox_id", "success")
}

######################################################################
# Validate the process fields from config.json.

allow_process(policy_oci, input_oci, sandbox_name) {
    policy_process := policy_oci.process
    input_process := input_oci.process

    print("allow_process", "terminal")
    policy_process.terminal         == input_process.terminal

    print("allow_process", "cwd")
    policy_process.cwd              == input_process.cwd

    print("allow_process", "capabilities")
    policy_process.capabilities     == input_process.capabilities

    print("allow_process", "noNewPrivileges")
    policy_process.noNewPrivileges  == input_process.noNewPrivileges

    print("allow_process", "allow_user")
    allow_user(policy_process, input_process)

    print("allow_process", "allow_args")
    allow_args(policy_process, input_process)

    print("allow_process", "allow_env")
    allow_env(policy_process, input_process, sandbox_name)

    print("allow_process", "success")
}

######################################################################
# OCI process.user field

allow_user(policy_process, input_process) {
    policy_user := policy_process.user
    input_user := input_process.user

    # TODO: compare the additionalGids field too after computing its value
    # based on /etc/passwd and /etc/group from the container image.
    policy_user.uid                 == input_user.uid
    policy_user.gid                 == input_user.gid
}

######################################################################
# OCI process.args field

allow_args(policy_process, input_process) {
    not policy_process.args
    not input_process.args
}
allow_args(policy_process, input_process) {
    policy_process.args == input_process.args
}

######################################################################
# OCI process.env field

allow_env(policy_process, input_process, sandbox_name) {
    every env_var in input_process.env {
        print("allow_env =>", env_var)
        allow_env_var(policy_process, input_process, env_var, sandbox_name)
    }

    print("allow_env", "success")
}

# Allow input env variables that are present in the policy data too.
allow_env_var(policy_process, input_process, env_var, sandbox_name) {
    print("allow_env_var 1", "policy_process.env[_] == env_var")
    policy_process.env[_] == env_var
    print("allow_env_var 1", "success")
}

# Allow "HOSTNAME=<sandbox_name>".
allow_env_var(policy_process, input_process, env_var, sandbox_name) {
    print("allow_env_var 2", "HOSTNAME")
    host_name_env_var := concat("", ["HOSTNAME=", sandbox_name])

    print(host_name_env_var, env_var)
    host_name_env_var == env_var

    print("allow_env_var 2", "success")
}

# Allow service-related env variables:

# "KUBERNETES_PORT_443_TCP_PROTO=tcp"
allow_env_var(policy_process, input_process, env_var, sandbox_name) {
    print("allow_env_var 3", "KUBERNETES_PORT_443_TCP_PROTO=tcp")

    name_value := split(env_var, "=")
    count(name_value) == 2

    name_value[1] == "tcp"

    name_components = split(name_value[0], "_")
    components_count := count(name_components)
    components_count >= 5
    name_components[components_count - 1] == "PROTO"
    name_components[components_count - 2] == "TCP"
    name_components[components_count - 4] == "PORT"
    port := name_components[components_count - 3]
    is_port(port)

    print("allow_env_var 3", "success")
}

# "KUBERNETES_PORT_443_TCP_PORT=443"
allow_env_var(policy_process, input_process, env_var, sandbox_name) {
    print("allow_env_var 4", "KUBERNETES_PORT_443_TCP_PORT=443")

    name_value := split(env_var, "=")
    count(name_value) == 2

    port = name_value[1]
    is_port(port)

    name_components = split(name_value[0], "_")
    components_count := count(name_components)
    components_count >= 5
    name_components[components_count - 1] == "PORT"
    name_components[components_count - 2] == "TCP"
    name_components[components_count - 3] == port
    name_components[components_count - 4] == "PORT"

    print("allow_env_var 4", "success")
}

# "KUBERNETES_PORT_443_TCP_ADDR=10.0.0.1"
allow_env_var(policy_process, input_process, env_var, sandbox_name) {
    print("allow_env_var 5", "KUBERNETES_PORT_443_TCP_ADDR=10.0.0.1")

    name_value := split(env_var, "=")
    count(name_value) == 2

    is_ip(name_value[1])

    name_components = split(name_value[0], "_")
    components_count := count(name_components)
    components_count >= 5
    name_components[components_count - 1] == "ADDR"
    name_components[components_count - 2] == "TCP"
    name_components[components_count - 4] == "PORT"
    port := name_components[components_count - 3]
    is_port(port)

    print("allow_env_var 5", "success")
}

# "KUBERNETES_SERVICE_HOST=10.0.0.1",
allow_env_var(policy_process, input_process, env_var, sandbox_name) {
    print("allow_env_var 6", "KUBERNETES_SERVICE_HOST=10.0.0.1")

    name_value := split(env_var, "=")
    count(name_value) == 2

    is_ip(name_value[1])

    name_components = split(name_value[0], "_")
    components_count := count(name_components)
    components_count >= 3
    name_components[components_count - 1] == "HOST"
    name_components[components_count - 2] == "SERVICE"

    print("allow_env_var 6", "success")
}

# "KUBERNETES_SERVICE_PORT=443",
allow_env_var(policy_process, input_process, env_var, sandbox_name) {
    print("allow_env_var 7", "KUBERNETES_SERVICE_PORT=443")

    name_value := split(env_var, "=")
    count(name_value) == 2

    is_port(name_value[1])

    name_components = split(name_value[0], "_")
    components_count := count(name_components)
    components_count >= 3
    name_components[components_count - 1] == "PORT"
    name_components[components_count - 2] == "SERVICE"

    print("allow_env_var 7", "success")
}

# "KUBERNETES_SERVICE_PORT_HTTPS=443",
allow_env_var(policy_process, input_process, env_var, sandbox_name) {
    print("allow_env_var 8", "KUBERNETES_SERVICE_PORT_HTTPS=443")

    name_value := split(env_var, "=")
    count(name_value) == 2

    is_port(name_value[1])

    name_components = split(name_value[0], "_")
    components_count := count(name_components)
    components_count >= 4
    name_components[components_count - 1] == "HTTPS"
    name_components[components_count - 2] == "PORT"
    name_components[components_count - 3] == "SERVICE"

    print("allow_env_var 8", "success")
}

# "KUBERNETES_PORT=tcp://10.0.0.1:443",
allow_env_var(policy_process, input_process, env_var, sandbox_name) {
    print("allow_env_var 9", "KUBERNETES_PORT=tcp://10.0.0.1:443")

    name_value := split(env_var, "=")
    count(name_value) == 2

    is_tcp_uri(name_value[1])

    name_components = split(name_value[0], "_")
    components_count := count(name_components)
    components_count >= 2
    name_components[components_count - 1] == "PORT"

    print("allow_env_var 9", "success")
}

# "KUBERNETES_PORT_443_TCP=tcp://10.0.0.1:443",
allow_env_var(policy_process, input_process, env_var, sandbox_name) {
    print("allow_env_var 10", "KUBERNETES_PORT_443_TCP=tcp://10.0.0.1:443")

    name_value := split(env_var, "=")
    count(name_value) == 2

    name_components = split(name_value[0], "_")
    components_count := count(name_components)
    components_count >= 4
    name_components[components_count - 1] == "TCP"
    name_components[components_count - 3] == "PORT"
    port := name_components[components_count - 2]
    is_port(port)

    is_tcp_uri(name_value[1])
    value_components = split(name_value[1], ":")
    count(value_components) == 3
    value_components[2] == port

    print("allow_env_var 10", "success")
}

is_ip(value) {
    bytes = split(value, ".")
    count(bytes) == 4

    is_ip_first_byte(bytes[0])
    is_ip_other_byte(bytes[1])
    is_ip_other_byte(bytes[2])
    is_ip_other_byte(bytes[3])
}
is_ip_first_byte(component) {
    number = to_number(component)
    number >= 1
    number <= 255
}
is_ip_other_byte(component) {
    number = to_number(component)
    number >= 0
    number <= 255
}

is_port(value) {
    number = to_number(value)
    number >= 1
    number <= 65635
}

# E.g., "tcp://10.0.0.1:443"
is_tcp_uri(value) {
    components = split(value, "//")
    count(components) == 2
    components[0] == "tcp:"

    ip_and_port = split(components[1], ":")
    count(ip_and_port) == 2
    is_ip(ip_and_port[0])
    is_port(ip_and_port[1])
}

######################################################################
# OCI root.path

allow_root_path(policy_oci, input_oci, bundle_id) {
    # Example policy: "path": "/run/kata-containers/shared/containers/$(bundle-id)/rootfs",
    policy_path := replace(policy_oci.root.path, "$(bundle-id)", bundle_id)
    policy_path == input_oci.root.path
}

######################################################################
# mounts

allow_mount(policy_oci, input_mount, bundle_id, sandbox_id) {
    some policy_mount in policy_oci.mounts
    policy_mount_allows(policy_mount, input_mount, bundle_id, sandbox_id)

    # TODO: are there any other required policy checks for mounts - e.g.,
    #       multiple mounts with same source or destination?
}

policy_mount_allows(policy_mount, input_mount, bundle_id, sandbox_id) {
    print("policy_mount_allows 1")
    policy_mount == input_mount
    print("policy_mount_allows 1 success")
}
policy_mount_allows(policy_mount, input_mount, bundle_id, sandbox_id) {
    print("policy_mount_allows 2")

    print("policy_mount_allows 2", "destination", input_mount.destination)
    policy_mount.destination    == input_mount.destination

    print("policy_mount_allows 2", "type")
    policy_mount.type           == input_mount.type

    print("policy_mount_allows 2", "options")
    policy_mount.options        == input_mount.options

    print("policy_mount_allows 2", "policy_mount_source_allows")
    policy_mount_source_allows(policy_mount, input_mount, bundle_id, sandbox_id)

    print("policy_mount_allows 2 success")
}

policy_mount_source_allows(policy_mount, input_mount, bundle_id, sandbox_id) {
    # E.g., "source": "^/run/kata-containers/shared/containers/$(bundle-id)-[a-z0-9]{16}-resolv.conf$",
    policy_source_regex := replace(policy_mount.source, "$(bundle-id)", bundle_id)
    regex.match(policy_source_regex, input_mount.source)
}
policy_mount_source_allows(policy_mount, input_mount, bundle_id, sandbox_id) {
    # E.g., "source": "^/run/kata-containers/shared/containers/$(sandbox-id)/rootfs/local/data$",
    policy_source_regex := replace(policy_mount.source, "$(sandbox-id)", sandbox_id)
    regex.match(policy_source_regex, input_mount.source)
}

######################################################################
# Storages

allow_storages(policy_storages, input_storages, sandbox_id) {
    # TODO: add support for storages used with tarfs.
    #count(policy_storages) == count(input_storages)

    #every input_storage in input_storages {
    #    policy_storage := policy_storages[_]
    #    allow_storage(policy_storage, input_storage, sandbox_id)
    #}
    true
}

allow_storage(policy_storage, input_storage, sandbox_id) {
    policy_storage.driver           == input_storage.driver
    policy_storage.driver_options   == input_storage.driver_options
    policy_storage.source           == input_storage.source
    policy_storage.options          == input_storage.options
    policy_storage.fs_group         == input_storage.fs_group

    allow_storage_mount_point(policy_storage, input_storage, sandbox_id)
}

allow_storage_mount_point(policy_storage, input_storage, sandbox_id) {
    # E.g., "mount_point": "^/run/kata-containers/shared/containers/$(sandbox-id)/rootfs/local/data$",
    mount_point_regex := replace(policy_storage.mount_point, "$(sandbox-id)", sandbox_id)
    regex.match(mount_point_regex, input_storage.mount_point)
}
