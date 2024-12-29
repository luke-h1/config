# shellcheck disable=SC2148
# shellcheck disable=SC2086
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
rm -f ~/.zcompdump
compinit
