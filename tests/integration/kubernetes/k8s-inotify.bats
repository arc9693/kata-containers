#!/usr/bin/env bats
#
# Copyright (c) 2021 Apple Inc.
#
# SPDX-License-Identifier: Apache-2.0
#

load "${BATS_TEST_DIRNAME}/../../common.bash"
load "${BATS_TEST_DIRNAME}/tests_common.sh"

setup() {
	[ "${KATA_HYPERVISOR}" == "firecracker" ] && skip "test not working see: ${fc_limitations}"
	[ "${KATA_HYPERVISOR}" == "fc" ] && skip "test not working see: ${fc_limitations}"
	issue_url="https://github.com/kata-containers/kata-containers/issues/8906"
	[ "${KATA_HYPERVISOR}" == "qemu-se" ] && skip "test not working for IBM Z LPAR (see ${issue_url})"
	get_pod_config_dir
        policy_settings_dir="$(create_tmp_policy_settings_dir "${pod_config_dir}")"
        auto_generate_policy "${policy_settings_dir}" "${pod_config_dir}/inotify-configmap-pod.yaml"
}

@test "configmap update works, and preserves symlinks" {
        pod_name="inotify-configmap-testing"

        # Create configmap for my deployment
        kubectl apply -f "${pod_config_dir}"/inotify-configmap.yaml

        # Create deployment that expects identity-certs
        kubectl apply -f "${pod_config_dir}"/inotify-configmap-pod.yaml
        kubectl wait --for=condition=Ready --timeout=$timeout pod "$pod_name"

        # Update configmap
        kubectl apply -f "${pod_config_dir}"/inotify-updated-configmap.yaml

        # Ideally we'd wait for the pod to complete...
        sleep 120

        # Verify we saw the update
        result=$(kubectl get pod "$pod_name" --output="jsonpath={.status.containerStatuses[]}")
        echo $result | grep -vq Error
}

teardown() {
	[ "${KATA_HYPERVISOR}" == "firecracker" ] && skip "test not working see: ${fc_limitations}"
	[ "${KATA_HYPERVISOR}" == "fc" ] && skip "test not working see: ${fc_limitations}"
	issue_url="https://github.com/kata-containers/kata-containers/issues/8906"
	[ "${KATA_HYPERVISOR}" == "qemu-se" ] && skip "test not working for IBM Z LPAR (see ${issue_url})"
	# Debugging information
	kubectl describe "pod/$pod_name"
	kubectl delete configmap cm
	kubectl delete pod "$pod_name"
}
