#!/usr/bin/env bats
#
# Copyright (c) 2020 Ant Group
#
# SPDX-License-Identifier: Apache-2.0
#

load "${BATS_TEST_DIRNAME}/../../common.bash"
load "${BATS_TEST_DIRNAME}/tests_common.sh"

setup() {
	[ "${KATA_HYPERVISOR}" == "dragonball" ] && skip "Test is currently failing, see: https://github.com/kata-containers/kata-containers/issues/7271"

	pod_name="pod-oom"
	get_pod_config_dir
}

@test "Test OOM events for pods" {
	[ "${KATA_HYPERVISOR}" == "dragonball" ] && skip "Test is currently failing, see: https://github.com/kata-containers/kata-containers/issues/7271"

	# Create pod
	kubectl create -f "${pod_config_dir}/$pod_name.yaml"

	# Check pod creation
	kubectl wait --for=condition=Ready --timeout=$timeout pod "$pod_name"

	# Check if OOMKilled
	cmd="kubectl get pods "$pod_name" -o jsonpath='{.status.containerStatuses[0].state.terminated.reason}' | grep OOMKilled"

	waitForProcess "$wait_time" "$sleep_time" "$cmd"

	rm -f "${pod_config_dir}/test_pod_oom.yaml"
}

teardown() {
	[ "${KATA_HYPERVISOR}" == "dragonball" ] && skip "Test is currently failing, see: https://github.com/kata-containers/kata-containers/issues/7271"

	# Debugging information
	kubectl describe "pod/$pod_name"
	kubectl get "pod/$pod_name" -o yaml

	kubectl delete pod "$pod_name"
}
