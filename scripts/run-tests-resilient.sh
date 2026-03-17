#!/bin/bash
# Resilient UI test runner: one test class at a time, bootstatus -b, retry on bootstrap crash.
# Usage: from repo root:
#   ./scripts/run-tests-resilient.sh              # all groups
#   ./scripts/run-tests-resilient.sh --group 4   # Group 4 only
#   ./scripts/run-tests-resilient.sh --class BarrioCursorUITests/CollectionsFlowTests

set -e

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_DIR="$REPO_ROOT/ios/BarrioCursor/BarrioCursor"
RESULTS_DIR="$REPO_ROOT/ios/test-results"
RESULTS_JSON="$RESULTS_DIR/results.json"
MAX_RETRIES=3
CLASS_TIMEOUT=300

# Test groups (one class per line for clarity)
GROUP_1="BarrioCursorUITests/SmokeTest"
GROUP_2="BarrioCursorUITests/NavigationTests BarrioCursorUITests/ButtonResponseTests"
GROUP_3="BarrioCursorUITests/AuthFlowTests BarrioCursorUITests/LoginFlowTests"
GROUP_4="BarrioCursorUITests/CollectionsFlowTests BarrioCursorUITests/DiscoveryFlowTests BarrioCursorUITests/EventDiscoveryTests2 BarrioCursorUITests/ProfileFlowTests BarrioCursorUITests/ProfileTests2"

get_device_id() {
    local id
    id=$(timeout 15 xcrun simctl list devices available 2>/dev/null | grep "iPhone 17 " | grep -v Pro | head -1 | sed -E 's/.*\(([A-F0-9-]+)\).*/\1/' || true)
    echo "$id"
}

# Destination string: use ID if we have it, else use name (works when simctl list is slow or device missing)
get_destination() {
    if [[ -n "$DEVICE_ID" ]]; then
        echo "platform=iOS Simulator,id=$DEVICE_ID"
    else
        # Fallback when get_device_id returns empty (e.g. simctl list slow)
        echo "platform=iOS Simulator,name=iPhone 17,OS=latest"
    fi
}

boot_simulator_ready() {
    local dev_id="$1"
    if [[ -z "$dev_id" ]]; then return 1; fi
    echo "   Waiting for simulator to be ready (bootstatus -b)..."
    if xcrun simctl bootstatus "$dev_id" -b 2>/dev/null; then
        sleep 2
        open -a Simulator 2>/dev/null || true
        sleep 1
        return 0
    fi
    # Fallback: boot then sleep
    xcrun simctl boot "$dev_id" 2>/dev/null || true
    sleep 5
    open -a Simulator 2>/dev/null || true
    sleep 2
    return 0
}

kill_test_runner() {
    pkill -f "BarrioCursorUITests-Runner" 2>/dev/null || true
    pkill -f "xcodebuild.*test-without-building" 2>/dev/null || true
    sleep 1
}

is_bootstrap_crash() {
    grep -q "signal kill before establishing connection\|signal abrt while preparing to run\|operation never finished bootstrapping" "$1" 2>/dev/null
}

run_one_class() {
    local class="$1"
    local log_path="$2"
    local result_bundle="$3"
    local retries=0
    local exit_code=1

    while [[ $retries -le $MAX_RETRIES ]]; do
        if [[ $retries -gt 0 ]]; then
            echo "   Retry $retries/$MAX_RETRIES: rebooting simulator..."
            xcrun simctl shutdown "$DEVICE_ID" 2>/dev/null || true
            sleep 2
            boot_simulator_ready "$DEVICE_ID"
            kill_test_runner
            sleep 2
        fi

        rm -rf "$result_bundle"
        cd "$PROJECT_DIR"
        set +e
        if command -v timeout >/dev/null 2>&1; then
            timeout "$CLASS_TIMEOUT" xcodebuild test-without-building \
                -scheme BarrioCursor \
                -destination "$DESTINATION" \
                -only-testing:"$class" \
                -resultBundlePath "$result_bundle" \
                -test-timeouts-enabled YES \
                -default-test-execution-time-allowance 120 \
                2>&1 | tee "$log_path"
        else
            xcodebuild test-without-building \
                -scheme BarrioCursor \
                -destination "$DESTINATION" \
                -only-testing:"$class" \
                -resultBundlePath "$result_bundle" \
                -test-timeouts-enabled YES \
                -default-test-execution-time-allowance 120 \
                2>&1 | tee "$log_path"
        fi
        exit_code=${PIPESTATUS[0]}
        set -e

        if [[ $exit_code -eq 0 ]]; then
            echo "   PASS"
            return 0
        fi
        if is_bootstrap_crash "$log_path"; then
            retries=$((retries + 1))
            continue
        fi
        echo "   FAIL (exit $exit_code)"
        return $exit_code
    done

    echo "   CRASH (bootstrap after $MAX_RETRIES retries)"
    return 2
}

# Parse args
GROUP_ARG=""
CLASS_ARG=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --group) GROUP_ARG="$2"; shift 2 ;;
        --class) CLASS_ARG="$2"; shift 2 ;;
        *) shift ;;
    esac
done

mkdir -p "$RESULTS_DIR"
DEVICE_ID=$(get_device_id)
DESTINATION=$(get_destination)

echo "Resilient UI test runner — portal. (BarrioCursor)"
echo "================================================"
echo "Destination: $DESTINATION"
echo ""

# Kill any stale test runner
kill_test_runner

# Ensure simulator is fully booted before building (only when we have an ID)
if [[ -n "$DEVICE_ID" ]]; then
    boot_simulator_ready "$DEVICE_ID"
else
    echo "   Using destination by name (simulator will be started by xcodebuild if needed)."
fi

echo "Building for testing..."
cd "$PROJECT_DIR"
if ! xcodebuild build-for-testing -scheme BarrioCursor -destination "$DESTINATION" -quiet 2>&1; then
    echo "Build failed."
    echo "{\"build\":\"fail\"}" > "$RESULTS_JSON"
    exit 1
fi
echo "Build OK."
echo ""

# Select classes to run
CLASSES=""
if [[ -n "$CLASS_ARG" ]]; then
    CLASSES="$CLASS_ARG"
elif [[ -n "$GROUP_ARG" ]]; then
    case "$GROUP_ARG" in
        1) CLASSES="$GROUP_1" ;;
        2) CLASSES="$GROUP_2" ;;
        3) CLASSES="$GROUP_3" ;;
        4) CLASSES="$GROUP_4" ;;
        all) CLASSES="$GROUP_1 $GROUP_2 $GROUP_3 $GROUP_4" ;;
        *) echo "Unknown group: $GROUP_ARG (use 1|2|3|4|all)"; exit 1 ;;
    esac
else
    CLASSES="$GROUP_1 $GROUP_2 $GROUP_3 $GROUP_4"
fi

# Run each class; collect results for agent
declare -a RESULTS
OVERALL=0
for class in $CLASSES; do
    short_name="${class##*/}"
    log_file="$RESULTS_DIR/${short_name}.log"
    echo -n "Running $short_name ... "
    start=$(date +%s)
    result_bundle="$RESULTS_DIR/${short_name}.xcresult"
    if run_one_class "$class" "$log_file" "$result_bundle"; then
        end=$(date +%s)
        RESULTS+=("{\"name\":\"$short_name\",\"status\":\"pass\",\"duration_s\":$((end - start))}")
    else
        status="fail"
        if is_bootstrap_crash "$log_file"; then status="crash"; OVERALL=2; fi
        RESULTS+=("{\"name\":\"$short_name\",\"status\":\"$status\",\"log\":\"ios/test-results/${short_name}.log\"}")
        [[ $OVERALL -eq 0 ]] && OVERALL=1
    fi
    # Allow memory to settle between classes
    sleep 3
done

# Write JSON summary for agent
printf '{"build":"pass","classes":[%s]}\n' "$(IFS=,; echo "${RESULTS[*]}")" > "$RESULTS_JSON"
echo ""
echo "Summary: $RESULTS_JSON"
exit $OVERALL
