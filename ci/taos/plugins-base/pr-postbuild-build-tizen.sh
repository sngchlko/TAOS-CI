#!/usr/bin/env bash

##
# Copyright (c) 2018 Samsung Electronics Co., Ltd. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#     http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

##
# @file     pr-postbuild-build-tizen.sh
# @brief    Build package with gbs command  to verify build validation on Tizen software platform
# @see      https://github.com/nnsuite/TAOS-CI
# @see      https://source.tizen.org/documentation/reference/git-build-system
# @author   Geunsik Lim <geunsik.lim@samsung.com>
# @note
# If the gbs command based on the QEMU/ARM facility is broken, please run "reboot" command,
# Or run the below statements to avoid the "reboot" procedure. 
# https://wiki.tizen.org/OSDev/qemu-accel
# $ echo -1 | sudo tee /proc/sys/fs/binfmt_misc/qemu-arm


# @brief [MODULE] ${BOT_NAME}/pr-postbuild-build-tizen-wait-queue
function pr-postbuild-build-tizen-wait-queue(){
    message="Trigger: wait queue. There are other build jobs and we need to wait.. The commit number is $input_commit."
    cibot_report $TOKEN "pending" "${BOT_NAME}/pr-postbuild-build-tizen-$1" "$message" "${CISERVER}${PRJ_REPO_UPSTREAM_LOCAL}/ci/${dir_commit}/" "$GITHUB_WEBHOOK_API/statuses/$input_commit"
}

# @brief [MODULE] ${BOT_NAME}/pr-postbuild-build-tizen-ready-queue
function pr-postbuild-build-tizen-ready-queue(){
    message="Trigger: ready queue. The commit number is $input_commit."
    cibot_report $TOKEN "pending" "${BOT_NAME}/pr-postbuild-build-tizen-$1" "$message" "${CISERVER}${PRJ_REPO_UPSTREAM_LOCAL}/ci/${dir_commit}/" "$GITHUB_WEBHOOK_API/statuses/$input_commit"
}

# @brief [MODULE] ${BOT_NAME}/pr-postbuild-build-tizen-run-queue
function pr-postbuild-build-tizen-run-queue(){
    message="Trigger: run queue. The commit number is $input_commit."
    cibot_report $TOKEN "pending" "${BOT_NAME}/pr-postbuild-build-tizen-$1" "$message" "${CISERVER}${PRJ_REPO_UPSTREAM_LOCAL}/ci/${dir_commit}/" "$GITHUB_WEBHOOK_API/statuses/$input_commit"

    echo -e "[MODULE] ${BOT_NAME}/pr-postbuild-build-tizen-$1: Check if the gbs command with '-A $1' can be successfully passed."
    pwd

    # check if dependent packages are installed
    # the required packages are gbs.
    check_cmd_dep sudo
    check_cmd_dep curl
    check_cmd_dep gbs

    # BUILD_MODE=0 : run the build task with gbs command without generating debugging information.
    # BUILD_MODE=1 : run the build task with gbs ommand with a debug file.
    # BUILD_MODE=99: skip the build task of the gbs command
    BUILD_MODE=$BUILD_MODE_TIZEN

    # TODO: We need to decide a prefix policy consistently for maintenance and
    # compatibility of TAOS-CI,
    # For example,
    # 1) _common_*****
    # 2) _nnstreamer_****
    # 3) _another_****

    # Put a timer in front of the build job to check a start time.
    time_start=$(date +"%s")

    # Build a package with gbs command.
    # TODO: Simplify the existing if...else statement for readability and maintenance
    echo -e "[DEBUG] the build task of gbs starts at : $(date -R)."
    if [[ "$TIZEN_GBS_PROFILE" != "" ]]; then
        _TIZEN_GBS_PROFILE="-P ${TIZEN_GBS_PROFILE}"
    else
        _TIZEN_GBS_PROFILE=""
    fi

    # TODO: If you want to support this option in the configuration file for flexibility and maintenance,
    # you may submit a PR in order to put the environment variable (e.g., CUSTOM_GBS_CONF{01|02|03})
    # into the ./config/config-environment.sh.
    CUSTOM_GBS_CONF01="./.TAOS-CI/.gbs.conf"
    CUSTOM_GBS_CONF02="./packaging/.gbs.conf"
    CUSTOM_GBS_CONF03="~/.gbs.conf"

    echo -e "[DEBUG] Checking if the $CUSTOM_GBS_CONF01 file exists or not."
    if [[ -f $CUSTOM_GBS_CONF01 ]]; then
        echo -e "[DEBUG] The $CUSTOM_GBS_CONF01 file exists."
        echo -e "[DEBUG] Building the package with the $CUSTOM_GBS_CONF01 file"
        gbs_build="sudo -Hu www-data gbs -c $CUSTOM_GBS_CONF01 build"
    elif [[ -f $CUSTOM_GBS_CONF02 ]]; then
        echo -e "[DEBUG] The $CUSTOM_GBS_CONF02 file exists."
        echo -e "[DEBUG] Building the package with the $CUSTOM_GBS_CONF02 file"
        gbs_build="sudo -Hu www-data gbs -c $CUSTOM_GBS_CONF02 build"
    elif [[ -f $CUSTOM_GBS_CONF03 ]]; then
        echo -e "[DEBUG] The $CUSTOM_GBS_CONF03 file exists."
        echo -e "[DEBUG] Building the package with the $CUSTOM_GBS_CONF03 file of the 'www-data' account."
        gbs_build="sudo -Hu www-data gbs build"
    else
        echo -e "[DEBUG] Oooops. We could not find anyone among the below three gbs configuration files."
        echo -e "[DEBUG] $CUSTOM_GBS_CONF01"
        echo -e "[DEBUG] $CUSTOM_GBS_CONF02"
        echo -e "[DEBUG] $CUSTOM_GBS_CONF03"
        exit 1
    fi

    if [[ $BUILD_MODE == 99 ]]; then
        echo -e "BUILD_MODE = 99"
        echo -e "Skipping 'the build task of gbs including the -A $1' procedure temporarily."
    elif [[ $BUILD_MODE == 1 ]]; then
        echo -e "BUILD_MODE = 1"
        $gbs_build \
        -A $1 \
        ${_TIZEN_GBS_PROFILE} \
        --clean \
        --define "_smp_mflags -j${CPU_NUM}" \
        --define "_pr_context pr-postbuild" \
        --define "_pr_number ${input_pr}" \
        --define "__ros_verify_enable 1" \
        --define "_pr_start_time ${input_date}" \
        --define "_skip_debug_rpm 1" \
        --buildroot ./GBS-ROOT/ 2> ../report/build_log_${input_pr}_tizen_$1_error.txt 1> ../report/build_log_${input_pr}_tizen_$1_output.txt
    else
        echo -e "BUILD_MODE = 0"
        # In case of x86_64 or i586
        if [[ $1 == "x86_64" || $1 == "i586" ]]; then
            $gbs_build \
            -A $1 \
            ${_TIZEN_GBS_PROFILE} \
            --clean \
            --define "_smp_mflags -j${CPU_NUM}" \
            --define "_pr_context pr-postbuild" \
            --define "_pr_number ${input_pr}" \
            --define "__ros_verify_enable 1" \
            --define "_pr_start_time ${input_date}" \
            --define "_skip_debug_rpm 1" \
            --define "unit_test 1" \
            --buildroot ./GBS-ROOT/ 2> ../report/build_log_${input_pr}_tizen_$1_error.txt 1> ../report/build_log_${input_pr}_tizen_$1_output.txt
        # In case of armv7l or aarch64
        else
            $gbs_build \
            -A $1 \
            ${_TIZEN_GBS_PROFILE} \
            --clean \
            --define "_smp_mflags -j${CPU_NUM}" \
            --define "_pr_context pr-postbuild" \
            --define "_pr_number ${input_pr}" \
            --define "__ros_verify_enable 1" \
            --define "_pr_start_time ${input_date}" \
            --define "_skip_debug_rpm 1" \
            --buildroot ./GBS-ROOT/ 2> ../report/build_log_${input_pr}_tizen_$1_error.txt 1> ../report/build_log_${input_pr}_tizen_$1_output.txt
        fi
    fi
    result=$?
    echo -e "[DEBUG] The build task of gbs finished at : $(date -R)."
    echo -e "[DEBUG] The variable result value is $result."

    # Put a timer behind the build job to check an end time.
    time_end=$(date +"%s")
    time_diff=$(($time_end-$time_start))
    time_build_cost="$(($time_diff / 60))m $(($time_diff % 60))s"

    # If the ./GBS-ROOT/ folder exists, let's remove this folder.
    # Note that this folder consume too many storage space (on average 9GiB).
    if [[ -d GBS-ROOT ]]; then
        mkdir ../$PACK_BIN_FOLDER
        echo "Archiving .rpm files for $1 ..."
        ls -al  ./GBS-ROOT/local/repos/tizen/$1/RPMS/
        sudo cp -arf ./GBS-ROOT/local/repos/tizen/$1/RPMS ../$PACK_BIN_FOLDER || echo -e "[DEBUG] Can't copy .rpm files."
        echo "Removing ./GBS-ROOT/ folder..."
        sudo rm -rf ./GBS-ROOT/
        if [[ $? -ne 0 ]]; then
            echo "[DEBUG][FAILED] Tizen/gbs: Oooops!!!!! ./GBS-ROOT folder is not removed."
        else
            echo "[DEBUG][PASSED] Tizen/gbs: It is okay. ./GBS-ROOT folder is successfully removed."
        fi
    fi
    echo "[DEBUG] The current directory: $(pwd)"

    if [[ $BUILD_MODE == 99 ]]; then
        # Do not run the build task of gbs command in order to skip unnecessary examination if there are no buildable files.
        echo -e "BUILD_MODE == 99"
        echo -e "[DEBUG] Let's skip the build task of gbs with '-A $1' procedure because there is not source code. All files may be skipped."
        echo -e "[DEBUG] So, we stop remained all tasks at this time."

        message="Skipped the build task of gbs with -A $1 procedure. No buildable files found. Commit number is $input_commit."
        cibot_report $TOKEN "success" "${BOT_NAME}/pr-postbuild-build-tizen-$1" "$message" "${CISERVER}${PRJ_REPO_UPSTREAM_LOCAL}/ci/${dir_commit}/" "$GITHUB_WEBHOOK_API/statuses/$input_commit"

        message="Skipped the build task of gbs with -A $1 procedure. Successfully all postbuild modules are passed. Commit number is $input_commit."
        cibot_report $TOKEN "success" "(INFO)${BOT_NAME}/pr-postbuild-group" "$message" "${CISERVER}${PRJ_REPO_UPSTREAM_LOCAL}/ci/${dir_commit}/" "$GITHUB_WEBHOOK_API/statuses/$input_commit"

        echo -e "[DEBUG] All postbuild modules are passed (the build task of gbs with -A $1 procedure is skipped) - it is ready to review!"
    else
        echo -e "BUILD_MODE != 99"
        echo -e "[DEBUG] The return value of the build task of gbs with -A $1 command is $result."
        # Let's check if build procedure is normally done.
        if [[ $result -eq 0 ]]; then
            echo -e "[DEBUG][PASSED] Successfully build checker is passed. Return value is ($result)."
            check_result="success"
        else
            echo -e "[DEBUG][FAILED] Oooops!!!!!! build checker is failed. Return value is ($result)."
            check_result="failure"
            global_check_result="failure"
        fi

        # Let's report build result of source code
        if [[ $check_result == "success" ]]; then
            message="Tizen.build Successful in $time_build_cost. Commit number is '$input_commit'."
            cibot_report $TOKEN "success" "${BOT_NAME}/pr-postbuild-build-tizen-$1" "$message" "${CISERVER}${PRJ_REPO_UPSTREAM_LOCAL}/ci/${dir_commit}/" "$GITHUB_WEBHOOK_API/statuses/$input_commit"
        else
            message="Tizen.build Failure after $time_build_cost. Commit number is $input_commit."
            cibot_report $TOKEN "failure" "${BOT_NAME}/pr-postbuild-build-tizen-$1" "$message" "${CISERVER}${PRJ_REPO_UPSTREAM_LOCAL}/ci/${dir_commit}/" "$GITHUB_WEBHOOK_API/statuses/$input_commit"

            export BUILD_TEST_FAIL=1
        fi
    fi

}
