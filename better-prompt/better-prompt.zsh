# Set vim
function __set_beam_cursor {
    echo -ne '\e[6 q'
}

function __set_block_cursor {
    echo -ne '\e[2 q'
}

function zle-keymap-select {
  case $KEYMAP in
    vicmd) __set_block_cursor;;
    viins|main) __set_beam_cursor;;
  esac
}
zle -N zle-keymap-select

function zle-line-init {
    __set_beam_cursor
}
zle -N zle-line-init

precmd() {
    __set_beam_cursor 
}

bindkey -v '^?' backward-delete-char
bindkey '^[[P' delete-char
autoload edit-command-line; zle -N edit-command-line
bindkey '^e' edit-command-line


# Execution time in prompt
prompt_command_execution_time() {
    local command_duration_seconds="${ZSH_COMMAND_DURATION:-0}"
    local time_threshold=1  # Minimum duration to show execution time
    local precision=0       # Decimal places for seconds

    (( command_duration_seconds >= time_threshold )) || return

    local formatted_time

    if (( command_duration_seconds < 60 )); then
        # Display seconds with precision if required
        if (( !precision )); then
          local -i sec=$((command_duration_seconds + 0.5))
        else
          local -F precision sec=command_duration_seconds
        fi
        formatted_time="${sec}s"
    else
        local -i duration=$((command_duration_seconds + 0.5))

        # Choose between displaying in H:M:S or Xd Xm Xs format
        formatted_time="$((duration % 60))s"
        if (( duration >= 60 )); then
            formatted_time="$((duration / 60 % 60))m $formatted_time"
            if (( duration >= 3600 )); then
                formatted_time="$((duration / 3600))h $formatted_time"
                if (( duration >= 86400 )); then
                    formatted_time="$((duration / 86400))d $formatted_time"
                fi
            fi
        fi
    fi

    # Customize the color and formatting here as needed
    echo "(${formatted_time}) "
}

preexec() {
  ZSH_COMMAND_START=$SECONDS
}

precmd() {
  ZSH_COMMAND_DURATION=$((SECONDS - ZSH_COMMAND_START))
}


# Set prompt
autoload -Uz add-zsh-hook vcs_info
setopt prompt_subst
add-zsh-hook precmd vcs_info
zstyle ':vcs_info:*' check-for-changes true
zstyle ':vcs_info:*' unstagedstr ' *'
zstyle ':vcs_info:*' stagedstr ' +'
zstyle ':vcs_info:git:*' formats       ' %b%u%c'
zstyle ':vcs_info:git:*' actionformats '%b|%a%u%c'

NEWLINE=$'\n'
truncated_path="%F{4}%0~$NEWLINE%{%k%}%f%F{5}❯%{%k%}%F{white}"

background_jobs="%(1j.%F{0}%K{0}%F{3}%{%k%}%F{0}%f.)"
non_zero_return_value="%(0?..%F{1}%f)"

PROMPT="%F{3}%n%F{2}@%F{6}%m%f:$truncated_path "

RPROMPT='$background_jobs $non_zero_return_value %F{cyan}${vcs_info_msg_0_}%f %F{10}$(prompt_command_execution_time)%F{8}%D{%H:%M:%S %m-%d}'
zle_highlight=(default:bold)



# 0) Choose backend *before* plugin autodetect to avoid wl-copy/xsel errors
if [[ -n "$TMUX" ]]; then
  export ZSH_SYSTEM_CLIPBOARD_METHOD=tmux
else
  export ZSH_SYSTEM_CLIPBOARD_METHOD=osc52
fi

# 1) Minimal helpers (same as upstream)
function _zsh_system_clipboard_command_exists() { type "$1" &> /dev/null; }
function _zsh_system_clipboard_error() {
  echo -e "\n\n  \033[41;37m ERROR \033[0m \033[01mzsh-system-clipboard:\033[0m $@\n" >&2
}
function _zsh_system_clipboard_suggest_to_install() {
  _zsh_system_clipboard_error "Could not find any available clipboard manager. Make sure you have \033[01m${@}\033[0m installed."
  return 1
}

# 2) Only run autodetect if method is still empty (we set it above, so this is skipped)
if [[ -z "$ZSH_SYSTEM_CLIPBOARD_METHOD" ]]; then
  case "$OSTYPE" {
    darwin*)
      if _zsh_system_clipboard_command_exists pbcopy && _zsh_system_clipboard_command_exists pbpaste; then
        ZSH_SYSTEM_CLIPBOARD_METHOD="pb"
      else
        _zsh_system_clipboard_suggest_to_install 'pbcopy, pbpaste'
      fi
      ;;
    linux-android*)
      if _zsh_system_clipboard_command_exists termux-clipboard-set && _zsh_system_clipboard_command_exists termux-clipboard-get; then
        ZSH_SYSTEM_CLIPBOARD_METHOD="termux"
      else
        _zsh_system_clipboard_suggest_to_install 'Termux:API (from Play Store), termux-api (from apt package)'
      fi
      ;;
    linux*|freebsd*)
      if _zsh_system_clipboard_command_exists wl-copy; then
        ZSH_SYSTEM_CLIPBOARD_METHOD="wlc"
      elif _zsh_system_clipboard_command_exists xsel; then
        ZSH_SYSTEM_CLIPBOARD_METHOD="xsc"
      elif _zsh_system_clipboard_command_exists xclip; then
        ZSH_SYSTEM_CLIPBOARD_METHOD="xcc"
      elif _zsh_system_clipboard_command_exists clip.exe; then
        ZSH_SYSTEM_CLIPBOARD_METHOD="wsl"
      else
        _zsh_system_clipboard_suggest_to_install 'wl-clipboard / xsel / xclip'
      fi
      ;;
    *)
      _zsh_system_clipboard_error 'Unsupported system.'; return 1 ;;
  esac
fi
unfunction _zsh_system_clipboard_error
unfunction _zsh_system_clipboard_suggest_to_install
unfunction _zsh_system_clipboard_command_exists

# 3) Backends
# tmux: write to system clipboard if supported (-w), otherwise just tmux buffer
function zsh-system-clipboard-set-tmux(){ tmux load-buffer -w - 2>/dev/null || tmux load-buffer -; }
function zsh-system-clipboard-get-tmux(){ tmux show-buffer 2>/dev/null || :; }

# wayland / x11 / others (kept for completeness)
function zsh-system-clipboard-set-wlc(){ wl-copy; }
function zsh-system-clipboard-get-wlc(){ wl-paste -n; }
function zsh-system-clipboard-set-wlp(){ wl-copy -p; }
function zsh-system-clipboard-get-wlp(){ wl-paste -p -n; }
function zsh-system-clipboard-set-wsl(){ clip.exe; }
function zsh-system-clipboard-get-wsl(){ powershell.exe -c '[Console]::Out.Write($(Get-Clipboard -Raw).tostring().replace("`r", ""))'; }
function zsh-system-clipboard-set-xsc(){ xsel -b -i; }
function zsh-system-clipboard-get-xsc(){ xsel -b -o; }
function zsh-system-clipboard-set-xsp(){ xsel -p -i; }
function zsh-system-clipboard-get-xsp(){ xsel -p -o; }
function zsh-system-clipboard-set-xcc(){ xclip -sel CLIPBOARD -in; }
function zsh-system-clipboard-get-xcc(){ xclip -sel CLIPBOARD -out; }
function zsh-system-clipboard-set-xcp(){ xclip -sel PRIMARY -in; }
function zsh-system-clipboard-get-xcp(){ xclip -sel PRIMARY -out; }
function zsh-system-clipboard-set-pb(){ pbcopy; }
function zsh-system-clipboard-get-pb(){ pbpaste; }
function zsh-system-clipboard-set-termux(){ termux-clipboard-set; }
function zsh-system-clipboard-get-termux(){ termux-clipboard-get; }

# OSC52 with shadow clipboard (so p/P works for local yanks)
typeset -g ZSC_SHADOW_CLIPBOARD=""
function zsh-system-clipboard-set-osc52() {
  local _in; _in="$(cat)"
  ZSC_SHADOW_CLIPBOARD="$_in"
  if command -v base64 >/dev/null 2>&1 && base64 --help 2>&1 | grep -q -- '-w'; then
    printf '\e]52;c;%s\a' "$(printf %s "$_in" | base64 -w0)"
  else
    printf '\e]52;c;%s\a' "$(printf %s "$_in" | base64 | tr -d '\n')"
  fi
}
# --- TRUE local clipboard read via OSC52 (Ghostty supports this) ---
# Query terminal for clipboard and capture the reply.
# Requires: Ghostty clipboard-read=allow (or you'll be prompted).
# --- TRUE local clipboard read via OSC52 (Ghostty) with tmux fallback ---
function zsh-system-clipboard-get-osc52() {
  # 0) tmux path: tmux can trigger an OSC52 read and store it in a buffer
  if [[ -n "$TMUX" ]]; then
    tmux refresh-client -l 2>/dev/null   # ask terminal for clipboard into tmux buffer
    local _tbuf
    _tbuf="$(tmux show-buffer 2>/dev/null || printf '')"
    if [[ -n "$_tbuf" ]]; then
      printf %s "$_tbuf"
      return 0
    fi
    # If that failed, drop through to raw OSC52 query.
  fi

  # 1) raw OSC52 read (Ghostty supports this; set clipboard-read = allow/ask)
  local tty="/dev/tty" ch buf=""
  # Query: OSC 52 ; c ; ?  BEL
  print -n $'\e]52;c;?\a' >| "$tty"

  # Read until BEL or ST (ESC \) or ~1s timeout
  local deadline=$((SECONDS + 1))
  exec {fd}<>"$tty"
  while (( SECONDS < deadline )); do
    IFS= read -r -u $fd -k 1 ch || break
    buf+="$ch"
    [[ "$ch" == $'\a' ]] && break
    [[ "$buf" == *$'\e\\' ]] && break
  done
  exec {fd}>&-

  # Extract the last OSC 52 response payload
  local osc="${buf##*$'\e]52;'}"
  [[ "$osc" == c\;* ]] && osc="${osc#c;}"
  # Strip possible terminators
  osc="${osc%$'\a'*}"
  osc="${osc%$'\e\\'*}"

  # Base64 decode (GNU: -d, BSD/macOS: -D)
  local out=""
  out="$(printf %s "$osc" | base64 -d 2>/dev/null)" || \
  out="$(printf %s "$osc" | base64 -D 2>/dev/null)" || out=""

  if [[ -n "$out" ]]; then
    printf %s "$out"
    return 0
  fi

  # 2) Fallback: whatever we last yanked in-shell via shadow buffer
  printf %s "$ZSC_SHADOW_CLIPBOARD"
}

# Common entry points
function zsh-system-clipboard-set(){ zsh-system-clipboard-set-${ZSH_SYSTEM_CLIPBOARD_METHOD}; }
function zsh-system-clipboard-get(){ zsh-system-clipboard-get-${ZSH_SYSTEM_CLIPBOARD_METHOD}; }

# 4) ZLE widgets (unchanged logic; now they use our osc52/tmux backends)
function zsh-system-clipboard-vicmd-vi-yank() {
  zle vi-yank
  if [[ "${KEYS}" == "y" && "${KEYMAP}" == 'viopp' ]]; then
    printf '%s\n' "$CUTBUFFER" | zsh-system-clipboard-set
  else
    printf '%s' "$CUTBUFFER" | zsh-system-clipboard-set
  fi
}
zle -N zsh-system-clipboard-vicmd-vi-yank
function zsh-system-clipboard-vicmd-vi-yank-eol(){ zle vi-yank-eol; printf '%s' "$CUTBUFFER" | zsh-system-clipboard-set; }
zle -N zsh-system-clipboard-vicmd-vi-yank-eol
function zsh-system-clipboard-vicmd-vi-yank-whole-line(){ zle vi-yank-whole-line; printf '%s\n' "$CUTBUFFER" | zsh-system-clipboard-set; }
zle -N zsh-system-clipboard-vicmd-vi-yank-whole-line

function zsh-system-clipboard-vicmd-vi-put() {
  local mode="$1" CLIPBOARD
  CLIPBOARD="$(zsh-system-clipboard-get; printf '%s' x)"; CLIPBOARD="${CLIPBOARD%x}"
  local RBUFFER_UNTIL_LINE_END="${RBUFFER%%$'\n'*}"
  if [[ "${CLIPBOARD[${#CLIPBOARD}]}" == $'\n' ]]; then
    if [[ "${RBUFFER_UNTIL_LINE_END}" == "${RBUFFER}" && "$mode" == "after" ]]; then
      CLIPBOARD=$'\n'"${CLIPBOARD%%$'\n'}"
    fi
    if [[ "$mode" == "after" ]]; then
      CURSOR="$(( CURSOR + ${#RBUFFER_UNTIL_LINE_END} ))"
    else
      local LBUFFER_UNTIL_LINE_END="${LBUFFER%$'\n'*}"
      CURSOR="$(( ${#LBUFFER_UNTIL_LINE_END} + 1 ))"
    fi
  fi
  if [[ "$mode" == "after" && ${#RBUFFER_UNTIL_LINE_END} != "0" ]]; then
    BUFFER="${BUFFER:0:$(( CURSOR + 1 ))}${CLIPBOARD}${BUFFER:$(( CURSOR + 1 ))}"
    CURSOR=$(( $#LBUFFER + $#CLIPBOARD ))
  else
    BUFFER="${BUFFER:0:$CURSOR}${CLIPBOARD}${BUFFER:$CURSOR}"
    CURSOR=$(( $#LBUFFER + $#CLIPBOARD - 1 ))
  fi
}
function zsh-system-clipboard-vicmd-vi-put-after(){ zsh-system-clipboard-vicmd-vi-put after; }
zle -N zsh-system-clipboard-vicmd-vi-put-after
function zsh-system-clipboard-vicmd-vi-put-before(){ zsh-system-clipboard-vicmd-vi-put before; }
zle -N zsh-system-clipboard-vicmd-vi-put-before

function zsh-system-clipboard-vicmd-vi-delete(){ local r=$REGION_ACTIVE; zle vi-delete; [[ "$KEYS" == d && $r == 0 ]] && printf '%s\n' "$CUTBUFFER" | zsh-system-clipboard-set || printf '%s' "$CUTBUFFER" | zsh-system-clipboard-set; }
zle -N zsh-system-clipboard-vicmd-vi-delete
function zsh-system-clipboard-vicmd-vi-delete-char(){ zle vi-delete-char; printf '%s' "$CUTBUFFER" | zsh-system-clipboard-set; }
zle -N zsh-system-clipboard-vicmd-vi-delete-char
function zsh-system-clipboard-vicmd-vi-change-eol(){ zle vi-change-eol; printf '%s' "$CUTBUFFER" | zsh-system-clipboard-set; }
zle -N zsh-system-clipboard-vicmd-vi-change-eol
function zsh-system-clipboard-vicmd-vi-kill-eol(){ zle vi-kill-eol; printf '%s' "$CUTBUFFER" | zsh-system-clipboard-set; }
zle -N zsh-system-clipboard-vicmd-vi-kill-eol
function zsh-system-clipboard-vicmd-vi-change-whole-line(){ zle vi-change-whole-line; printf '%s\n' "$CUTBUFFER" | zsh-system-clipboard-set; }
zle -N zsh-system-clipboard-vicmd-vi-change-whole-line
function zsh-system-clipboard-vicmd-vi-change(){ zle vi-change; printf '%s' "$CUTBUFFER" | zsh-system-clipboard-set; }
zle -N zsh-system-clipboard-vicmd-vi-change
function zsh-system-clipboard-vicmd-vi-substitue(){ zle vi-substitue; printf '%s' "$CUTBUFFER" | zsh-system-clipboard-set; }
zle -N zsh-system-clipboard-vicmd-vi-substitue
function zsh-system-clipboard-vicmd-vi-backward-delete-char(){ zle vi-backward-delete-char; printf '%s' "$CUTBUFFER" | zsh-system-clipboard-set; }
zle -N zsh-system-clipboard-vicmd-vi-backward-delete-char

function zsh-system-clipboard-visual-put-replace-selection(){
  local PUT REPLACED
  PUT="$(zsh-system-clipboard-get; printf '%s' x)"; PUT="${PUT%x}"
  zsh-system-clipboard-vicmd-vi-delete
  REPLACED="$(zsh-system-clipboard-get; printf '%s' x)"; REPLACED="${REPLACED%x}"
  printf '%s' "$PUT" | zsh-system-clipboard-set
  zsh-system-clipboard-vicmd-vi-put-before
  printf '%s' "$REPLACED" | zsh-system-clipboard-set
}
zle -N zsh-system-clipboard-visual-put-replace-selection

# Bind keys to widgets (unchanged)
function () {
  if [[ -n "$ZSH_SYSTEM_CLIPBOARD_DISABLE_DEFAULT_MAPS" ]]; then return; fi
  local binded_keys i parts key cmd keymap
  for keymap in vicmd visual emacs; do
    binded_keys=(${(f)"$(bindkey -M $keymap)"})
    for (( i = 1; i < ${#binded_keys[@]}; ++i )); do
      parts=("${(z)binded_keys[$i]}")
      key="${parts[1]}"; cmd="${parts[2]}"
      if (( $+functions[zsh-system-clipboard-$keymap-$cmd] )); then
        eval bindkey -M $keymap $key zsh-system-clipboard-$keymap-$cmd
      fi
    done
  done
}
