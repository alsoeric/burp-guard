# .bash_profile

# 1. First, set up all environment variables, PATH, and completions
PATH=$PATH:$HOME/.local/bin:$HOME/bin:$HOME/.cargo/bin
export PATH

if command -v jj >/dev/null 2>&1; then
    source <(COMPLETE=bash jj)
fi

# 2. Then source ~/.bashrc (which triggers dtach_auto at the bottom)
if [ -f ~/.bashrc ]; then
    . ~/.bashrc
fi
