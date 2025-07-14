# Useful functions

# Create directory and cd into it
mkcd() {
    mkdir -p "$1" && cd "$1"
}

# Find and grep in files
fgrep() {
    find . -type f -name "*$1*" -exec grep -l "$2" {} \;
}

# Quick backup of a file
backup() {
    cp "$1" "$1.backup.$(date +%Y%m%d_%H%M%S)"
}

# Extract various archive formats
extract() {
    if [ -f "$1" ]; then
        case "$1" in
            *.tar.bz2) tar xjf "$1" ;;
            *.tar.gz) tar xzf "$1" ;;
            *.bz2) bunzip2 "$1" ;;
            *.rar) unrar x "$1" ;;
            *.gz) gunzip "$1" ;;
            *.tar) tar xf "$1" ;;
            *.tbz2) tar xjf "$1" ;;
            *.tgz) tar xzf "$1" ;;
            *.zip) unzip "$1" ;;
            *.Z) uncompress "$1" ;;
            *.7z) 7z x "$1" ;;
            *) echo "'$1' cannot be extracted via extract()" ;;
        esac
    else
        echo "'$1' is not a valid file"
    fi
}

# Weather function
weather() {
    curl -s "wttr.in/$1"
}

# Port check
port() {
    lsof -i :"$1"
}