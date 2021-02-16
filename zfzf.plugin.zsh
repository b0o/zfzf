#!/usr/bin/env zsh

# fzf path finding filesystem navigation thing
#
# Copyright (C) 2021 Maddison Hellstrom <https://github.com/b0o>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

#
# key bindings:
#   - return:            accept final
#   - alt-return:        accept final (absolute)
#   - esc:               escape
#   - ctrl-g:            escape (absolute)
#   - alt-o:             accept query
#   - ctrl-d:            accept query final
#   - alt-P              append query
#   - ctrl-o:            replace query
#   - alt-i:             descend into directory or accept file
#   - alt-u:             ascend into parent directory
#   - alt-U              ascend to next existing ancestor
#   - ctrl-n:            next
#   - alt-n:             next
#   - tab:               next
#   - down:              next
#   - ctrl-p:            prev
#   - alt-p:             prev
#   - shift-tab:         prev
#   - up:                prev
function _zfzf () {
  local left="$LBUFFER"
  local right="$RBUFFER"
  local input="$*"
  if [[ -z "$input" && -n "$BUFFER" ]]; then
    zmodload -e zsh/pcre || zmodload zsh/pcre

    # Split before word adjacent to the left of the cursor
    pcre_compile -- '^(?U)((.*\s+)*)((\S|\\\s)+)$'
    if [[ -n "$LBUFFER" ]] && pcre_match -a mat -- "$LBUFFER"; then
      input="${mat[3]//(#m)\\/}"
      left="${LBUFFER:0:$((${#LBUFFER} - ${#input}))}"
    fi

    # Split after word adjacent to the right of the cursor
    pcre_compile -- '^((\\\s|\S)+)((\s+.*)*)$'
    if [[ -n "$RBUFFER" ]] && pcre_match -a mat -- "$RBUFFER"; then
      right="${mat[3]}"
      input="${input}${mat[1]//(#m)\\/}"
    fi
  fi

  local path_orig="${input:-}"
  path_orig=${~path_orig}     # expand tilde
  path_orig="${(e)path_orig}" # expand variables

  local path_orig_absolute
  local relative="$PWD"
  if [[ "$path_orig" =~ ^/ ]]; then
    path_orig_absolute="$path_orig"
    relative="/"
  else
    path_orig_absolute="$(realpath -m "${path_orig:-.}")"
  fi

  local fzf_query=""
  if ! [[ -e "$path_orig_absolute" ]]; then
    fzf_query="$(basename "$path_orig")"
    path_orig="$(dirname "$path_orig")"
    path_orig_absolute="$(dirname "$path_orig_absolute")"
  fi

  local fzf_preview=(
    'f="$(realpath -m "'"$path_orig_absolute"'/{}")";'
    'bat --color always "$f" 2>/dev/null || exa --tree --level=1 --color=always "$f" 2>/dev/null || stat "$f" 2>/dev/null'
  )

  LBUFFER="${left}${path_orig}"
  zle reset-prompt

  local res
  res="$(
    {
      {
        find "$path_orig_absolute" -mindepth 1 -maxdepth 1 -type b -or -type c -printf "${fg_bold[yellow]}%f${reset_color}\\n";
        find "$path_orig_absolute" -mindepth 1 -maxdepth 1 -type f -not -executable -printf "${fg_no_bold[default]}%f${reset_color}\\n";
        find "$path_orig_absolute" -mindepth 1 -maxdepth 1 -type f -executable -printf "${fg_no_bold[green]}%f${reset_color}\\n";
        find "$path_orig_absolute" -mindepth 1 -maxdepth 1 -type l -printf "${fg_no_bold[cyan]}%f${reset_color}\\n";
        find "$path_orig_absolute" -mindepth 1 -maxdepth 1 -type p -printf "${fg_no_bold[yellow]}%f${reset_color}\\n";
        find "$path_orig_absolute" -mindepth 1 -maxdepth 1 -type s -printf "${fg_bold[magenta]}%f${reset_color}\\n";
        find "$path_orig_absolute" -mindepth 1 -maxdepth 1 -not '(' -type b -or -type c -or -type f -or -type l -or -type p -or -type s -or -type d ')' -printf "${fg_no_bold[red]}%f${reset_color}\\n";
      } | sort -k 1.8 # The '-k 1.8' argument tells sort to skip the first 8 characters of each line, which happens to be the length of the ANSI color code escape sequences
      find "$path_orig_absolute" -mindepth 1 -maxdepth 1 -type d -printf "${fg_bold[blue]}%f${reset_color}\\n";
      printf "${fg_bold[white]}%s${reset_color}\n" "." ".."
    } 2>/dev/null \
      | fzf \
          --reverse --no-sort --ansi --height='50%' --header="$path_orig_absolute" \
          --query="$fzf_query" --print-query --cycle \
          --expect='ctrl-d,alt-return,ctrl-g,alt-P,alt-o,alt-i,alt-u,alt-U' \
          --bind='ctrl-o:replace-query,tab:down,btab:up,alt-n:down,alt-p:up' \
          --preview="bash -c '${fzf_preview[*]}'")"

  local -i code=$?

  local path_new
  local query key match
  local -i esc=0
  case $code in
  0|1|130)
    query="$(head -1 <<<"$res")"
    ;|

  0|1)
    key="$(head -2 <<<"$res" | tail -1)"

    case "${key:-}" in
    "alt-u")
      path_new=".."
      ;;
    "ctrl-d"|"alt-o"|"alt-P")
      path_new="${query:-}"
      ;;
    "alt-U"|"ctrl-g")
      path_new="."
      ;;
    esac
    ;|

  # Match
  0)
    path_new="${path_new:-$(tail -1 <<<"$res")}"
    ;;

  # No match
  1)
    ;;

  # Interrupted with CTRL-C or ESC
  130)
    esc=1
    path_new=""
    ;;

  # Error
  2|*)
    return 1
    ;;
  esac

  if [[ "$key" != "alt-o" && "$key" != "ctrl-d" && $esc -eq 0 ]]; then
    path_new="${path_orig:+$path_orig/}${path_new}"
    path_new="$(realpath -m --relative-to="$relative" "${path_new:-.}")"

    if [[ "$key" == "alt-U" ]]; then
      local -i alt_u_once=0 # we want the following loop to run at least once
      while [[ $alt_u_once -eq 0 || ! -e "$path_new" ]]; do
        alt_u_once=1
        path_new="$(realpath -m --relative-to="$relative" "${path_new}/..")"
      done
    fi

    if [[ "$relative" == "/" ]]; then
      path_new="/${path_new}"
    fi
  fi

  if [[ "$key" == "alt-return" || "$key" == "ctrl-g" ]]; then
    path_new="$(realpath -m "$path_new")"
  fi

  if [[ $esc -eq 1 && -z "$path_new" && -n "$input" ]]; then
    path_new="$input"
  fi

  LBUFFER="${left}${path_new}"
  RBUFFER="$right"
  zle reset-prompt

  if [[ "$key" =~ ^alt-[uUoP]$ || ( "$key" == "alt-i" && ( ! -e "$path_new" || -d "$path_new" ) ) ]]; then
    _zfzf
  fi
}

zle -N zfzf _zfzf

if [[ "${ZFZF_DISABLE_BINDINGS:-0}" -eq 0 ]]; then
  bindkey "^[." zfzf
fi
