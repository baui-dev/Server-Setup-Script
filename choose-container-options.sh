#!/bin/bash
# Combined container options module
# This script delegates to container-engine-config.sh and container-manager-config.sh.
# It is kept for backwards-compatibility and as a convenience entry point.
# Both prompt_container_engine() and prompt_container_manager() must be
# available (sourced by setup.sh before this file is called).

# Interactive selection: engine then manager, in one flow.
choose_all_container_options() {
    prompt_container_engine
    prompt_container_manager
}
