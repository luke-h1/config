#!/bin/bash
set -e
cd "$(dirname "$0")/.."

INSTALL_GLOBAL=
while [[ $# -gt 0 ]]; do
    case $1 in
        -g|--global) INSTALL_GLOBAL=1; shift ;;
        *) echo "Usage: $0 [-g|--global]  (default: project-level; -g = install globally)"; exit 1 ;;
    esac
done

AGENTS=(-a cursor -a claude-code -a codex)
if [[ -n "$INSTALL_GLOBAL" ]]; then
    GLOBAL_FLAG=(-g)
    echo "Installing skills globally"
else
    GLOBAL_FLAG=()
    echo "Installing skills at project level. Use -g or --global to install globally."
fi

SKILLS=(
    # react native / native
    "bunx skills add https://github.com/expo/skills --skill building-native-ui"
    "bunx skills add https://github.com/expo/skills --skill native-data-fetching"
    "bunx skills add https://github.com/expo/skills --skill upgrading-expo"
    "bunx skills add https://github.com/expo/skills --skill expo-dev-client"
    "bunx skills add https://github.com/expo/skills --skill expo-deployment"
    "bunx skills add https://github.com/expo/skills --skill expo-cicd-workflows"
    "bunx skills add https://github.com/expo/skills --skill use-dom"
    "bunx skills add https://github.com/vercel-labs/agent-skills --skill vercel-react-native-skills"
    "bunx skills add https://github.com/callstackincubator/agent-skills --skill react-native-best-practices"
    "bunx skills add callstackincubator/agent-device"
    "bunx skills add react-navigation/skills"
    "bunx skills add software-mansion-labs/skills"
    "bunx skills add https://github.com/twostraws/swiftui-agent-skill --skill swiftui-pro"

    # generic
    "bunx skills add mattpocock/skills"

    # frontend
    "bunx skills add https://github.com/vercel-labs/agent-skills --skill vercel-react-best-practices"
    "bunx skills add https://github.com/anthropics/skills --skill frontend-design"
    "bunx skills add https://github.com/dammyjay93/interface-design --skill interface-design"
    "bunx skills add https://github.com/vercel-labs/agent-skills --skill web-design-guidelines"
    "bunx skills add https://github.com/vercel-labs/agent-browser --skill agent-browser"
    "bunx skills add https://github.com/vercel-labs/agent-skills --skill vercel-composition-patterns"
    "bunx skills add https://github.com/coreyhaines31/marketingskills --skill analytics-tracking"

    # testing
    "bunx skills add https://github.com/currents-dev/playwright-best-practices-skill --skill playwright-best-practices"

    # observability
    "bunx skills add https://cli.sentry.dev"


    # backend
    "bunx skills add https://github.com/wshobson/agents --skill dotnet-backend-patterns"
    "bunx skills add https://github.com/jeffallan/claude-skills --skill golang-pro"
)

for cmd in "${SKILLS[@]}"; do
    echo "→ $cmd"
    eval "$cmd" "${AGENTS[@]}" -y "${GLOBAL_FLAG[@]}"
done

echo "Done. Installed skills (cursor + claude-code):"
bunx skills list -a cursor -a claude-code "${GLOBAL_FLAG[@]}"
