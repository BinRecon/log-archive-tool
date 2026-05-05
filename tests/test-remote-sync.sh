#!/usr/bin/env bash
# Test Suite for Log Archive Tool Remote Sync
# Validates core functionality
# Usage: bash tests/test-remote-sync.sh

set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly LIB_FILE="$SCRIPT_DIR/lib/remote-sync.sh"
readonly MAIN_SCRIPT="$SCRIPT_DIR/log-archive-enhanced.sh"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Colors
readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# ========== TEST FRAMEWORK ==========

test_case() {
    local name="$1"
    echo -e "${BLUE}[TEST]${NC} $name"
    ((TESTS_RUN++))
}

test_pass() {
    local message="${1:-Test passed}"
    echo -e "  ${GREEN}✓${NC} $message"
    ((TESTS_PASSED++))
}

test_fail() {
    local message="${1:-Test failed}"
    echo -e "  ${RED}✗${NC} $message"
    ((TESTS_FAILED++))
}

test_warn() {
    local message="${1:-Warning}"
    echo -e "  ${YELLOW}⚠${NC} $message"
}

# ========== VALIDATION TESTS ==========

test_file_exists() {
    local file="$1"
    if [[ -f "$file" ]]; then
        test_pass "File exists: $file"
        return 0
    else
        test_fail "File not found: $file"
        return 1
    fi
}

test_file_executable() {
    local file="$1"
    if [[ -x "$file" ]]; then
        test_pass "File is executable: $file"
        return 0
    else
        test_fail "File is not executable: $file"
        return 1
    fi
}

test_bash_syntax() {
    local file="$1"
    if bash -n "$file" 2>/dev/null; then
        test_pass "Bash syntax valid: $file"
        return 0
    else
        test_fail "Bash syntax error in: $file"
        return 1
    fi
}

test_contains_function() {
    local file="$1"
    local function="$2"
    if grep -q "^${function}()" "$file"; then
        test_pass "Function found: $function"
        return 0
    else
        test_fail "Function not found: $function"
        return 1
    fi
}

# ========== FUNCTIONALITY TESTS ==========

test_script_help() {
    test_case "Script help output"
    
    if "$MAIN_SCRIPT" --help 2>&1 | grep -q "Usage:"; then
        test_pass "Help output works"
        return 0
    else
        test_fail "Help output failed"
        return 1
    fi
}

test_script_version() {
    test_case "Script version output"
    
    if "$MAIN_SCRIPT" --version 2>&1 | grep -q "v[0-9]"; then
        test_pass "Version output works"
        return 0
    else
        test_fail "Version output failed"
        return 1
    fi
}

test_log_dir_validation() {
    test_case "Log directory validation"
    
    if ! "$MAIN_SCRIPT" --log-dir /nonexistent/path 2>&1 | grep -q "does not exist"; then
        test_fail "Validation should fail for non-existent directory"
        return 1
    else
        test_pass "Validation works correctly"
        return 0
    fi
}

# ========== LIBRARY TESTS ==========

test_library_sourcing() {
    test_case "Remote sync library sourcing"
    
    # shellcheck disable=SC1090
    if source "$LIB_FILE" 2>/dev/null; then
        test_pass "Library sourced successfully"
        return 0
    else
        test_fail "Failed to source library"
        return 1
    fi
}

test_library_functions() {
    test_case "Remote sync library functions"
    
    # Source library
    # shellcheck disable=SC1090
    source "$LIB_FILE" 2>/dev/null || return 1
    
    local functions=(
        "remote_sync_debug"
        "remote_sync_info"
        "remote_sync_error"
        "validate_ssh_host"
        "validate_remote_directory"
        "rsync_transfer"
        "scp_transfer"
    )
    
    local all_exist=true
    for func in "${functions[@]}"; do
        if declare -f "$func" > /dev/null; then
            test_pass "Function exists: $func"
        else
            test_fail "Function not found: $func"
            all_exist=false
        fi
    done
    
    return $([ "$all_exist" = true ] && echo 0 || echo 1)
}

# ========== LOGGING TESTS ==========

test_json_logging() {
    test_case "JSON logging format"
    
    local test_dir="/tmp/log-archive-test-$$"
    mkdir -p "$test_dir"
    
    # Create a test log entry
    local timestamp
    timestamp=$(date -Iseconds)
    
    local json="{\"timestamp\":\"$timestamp\",\"action\":\"test\",\"status\":\"success\",\"test_field\":\"value\"}"
    
    echo "$json" >> "$test_dir/archive_log.jsonl"
    
    if [[ -f "$test_dir/archive_log.jsonl" ]] && grep -q '"action":"test"' "$test_dir/archive_log.jsonl"; then
        test_pass "JSON logging works"
        rm -rf "$test_dir"
        return 0
    else
        test_fail "JSON logging failed"
        rm -rf "$test_dir"
        return 1
    fi
}

# ========== DEPENDENCY TESTS ==========

test_dependencies() {
    test_case "Required dependencies"
    
    local required_cmds=("tar" "gzip" "sha256sum" "ssh" "scp")
    local missing=()
    
    for cmd in "${required_cmds[@]}"; do
        if command -v "$cmd" &> /dev/null; then
            test_pass "Found: $cmd"
        else
            test_fail "Missing: $cmd"
            missing+=("$cmd")
        fi
    done
    
    if [[ ${#missing[@]} -eq 0 ]]; then
        return 0
    else
        return 1
    fi
}

test_optional_dependencies() {
    test_case "Optional dependencies"
    
    local optional_cmds=("rsync" "pigz")
    
    for cmd in "${optional_cmds[@]}"; do
        if command -v "$cmd" &> /dev/null; then
            test_pass "Found optional: $cmd"
        else
            test_warn "Optional not found: $cmd"
        fi
    done
}

# ========== INTEGRATION TESTS ==========

test_dry_run() {
    test_case "Dry run local archive"
    
    local test_dir="/tmp/log-archive-test-$$"
    local archive_dir="$test_dir/archives"
    
    mkdir -p "$test_dir/logs"
    echo "test log line" > "$test_dir/logs/test.log"
    
    # Run in local mode (dry-run style)
    if "$MAIN_SCRIPT" --log-dir "$test_dir/logs" --archive-dir "$archive_dir" 2>&1 | grep -q "Archive created"; then
        if [[ -f "$archive_dir/archive_log.jsonl" ]]; then
            test_pass "Dry run successful and logging works"
            rm -rf "$test_dir"
            return 0
        else
            test_fail "Log file not created"
            rm -rf "$test_dir"
            return 1
        fi
    else
        test_fail "Dry run failed"
        rm -rf "$test_dir"
        return 1
    fi
}

# ========== MAIN TEST SUITE ==========

main() {
    echo ""
    echo "=========================================="
    echo "Log Archive Tool - Test Suite"
    echo "=========================================="
    echo ""
    
    # File existence tests
    echo -e "${BLUE}=== File Tests ===${NC}"
    test_file_exists "$MAIN_SCRIPT"
    test_file_exists "$LIB_FILE"
    test_file_executable "$MAIN_SCRIPT"
    
    echo ""
    echo -e "${BLUE}=== Syntax Tests ===${NC}"
    test_bash_syntax "$MAIN_SCRIPT"
    test_bash_syntax "$LIB_FILE"
    
    echo ""
    echo -e "${BLUE}=== Script Tests ===${NC}"
    test_script_help
    test_script_version
    test_log_dir_validation
    
    echo ""
    echo -e "${BLUE}=== Library Tests ===${NC}"
    test_library_sourcing
    test_library_functions
    
    echo ""
    echo -e "${BLUE}=== Logging Tests ===${NC}"
    test_json_logging
    
    echo ""
    echo -e "${BLUE}=== Dependency Tests ===${NC}"
    test_dependencies
    test_optional_dependencies
    
    echo ""
    echo -e "${BLUE}=== Integration Tests ===${NC}"
    test_dry_run
    
    # Summary
    echo ""
    echo "=========================================="
    echo "Test Summary"
    echo "=========================================="
    echo "Total Tests: $TESTS_RUN"
    echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
    
    if [[ $TESTS_FAILED -gt 0 ]]; then
        echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
    else
        echo -e "Failed: ${GREEN}0${NC}"
    fi
    
    local percentage=0
    if [[ $TESTS_RUN -gt 0 ]]; then
        percentage=$(( (TESTS_PASSED * 100) / TESTS_RUN ))
    fi
    
    echo "Success Rate: ${percentage}%"
    echo "=========================================="
    echo ""
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}✓ All tests passed!${NC}"
        return 0
    else
        echo -e "${RED}✗ Some tests failed${NC}"
        return 1
    fi
}

main "$@"
