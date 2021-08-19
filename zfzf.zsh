#!/usr/bin/env zsh

# fzf path finding filesystem navigation thing
#
# Copyright (C) 2021 Maddison Hellstrom <https://github.com/b0o>, MIT License.

function zfzf () {
  local version="v0.2.0"

  local mode="standalone"

  local opt OPTARG
  local -i OPTIND
  while getopts "hcz" opt "$@"; do
    case "$opt" in
      h)
        cat <<EOF
zfzf $version

zfzf is a fzf-based file picker for zsh which allows you to easily navigate the
directory hierarchy and pick files using keybindings.

zfzf can be used as a standalone program, as an explicit zle widget, and as a
file path completion. By default, zfzf can be explicitly triggered with Alt-.
(this is configurable with the ZFZF_ZSH_BINDING option).

If you would like to use zfzf as your file completion when you press tab, you
should call the enable-zfzf-tab function in your .zshrc. If you use other
completion plugins like fzf-tab, you should call enable-zfzf-tab after all
other plugins have been loaded and enabled. You can later call disable-zfzf-tab
to restore the prior completion function.

Configuration Options
  Environment Variable          Default Value

  ZFZF_ENABLE_COLOR             1
    When enabled, files and previews will be colorized.

  ZFZF_ENABLE_PREVIEW           1
    When enabled, the focused item will be displayed in the fzf preview window.

  ZFZF_ENABLE_DOT_DOTDOT        1
    When enabled, display '.' and '..' at the top of the file listing.

  ZFZF_ZSH_BINDING              ^[. (Alt-.)
    Sets the keybinding sequence used to trigger zfzf. If set to the empty
    string, zfzf will not be bound. You can create a keybinding yourself by
    binding to the zfzf zle widget. See zshzle(1) for more information on key
    bindings.

  ZFZF_ENABLE_BAT               2
  ZFZF_ENABLE_EXA               2
    These options control zfzf's use of non-standard programs. Valid values
    include:
      - 0: Disable program
      - 1: Enable program (Force)
      - 2: Enable program (Optional)
    If the value 2 is used, the program will be enabled only if it is found in
    the PATH or if its path is explicitly specified as described below.

  ZFZF_BAT_PATH                 None
  ZFZF_EXA_PATH                 None
    These options allow paths to non-standard programs to be manually
    specified.

Default Key Bindings

  return             accept final
  alt-return         accept final (return absolute path)
  esc                escape
  ctrl-g             escape (return absolute path)
  alt-o              accept query
  ctrl-d             accept query final
  alt-P              append query
  ctrl-o             replace query
  alt-i              descend into directory or accept file
  alt-.              descend into directory or accept file
  alt-u              ascend into parent directory
  alt->              ascend into parent directory
  alt-U              ascend to next existing ancestor

EOF
        return 0
        ;;
      c)
        mode="completion"
        ;;
      z)
        mode="zle"
        ;;
      \?)
        return 1
        ;;
    esac
  done

  local -a opts=("${@:1:$((OPTIND-1))}")
  shift $((OPTIND - 1))

  # --- Legacy Configuration Options --- #
  if [[ -v ZFZF_NO_COLORS ]]; then
    echo >&2
    echo "Warning: ZFZF_NO_COLORS is deprecated in favor of ZFZF_ENABLE_COLOR." >&2
    echo "See zfzf -h for more information." >&2
    if [[ $zle -eq 1 ]]; then
      zle reset-prompt
    fi
    if [[ ! -v ZFZF_ENABLE_COLOR ]]; then
      if [[ ZFZF_NO_COLORS -eq 1 ]]; then
        local -i ZFZF_ENABLE_COLOR=0
      else
        local -i ZFZF_ENABLE_COLOR=1
      fi
    fi
  fi

  if [[ -v ZFZF_DOT_DOTDOT ]]; then
    echo >&2
    echo "Warning: ZFZF_DOT_DOTDOT is deprecated in favor of ZFZF_ENABLE_DOT_DOTDOT." >&2
    echo "See zfzf -h for more information." >&2
    if [[ $zle -eq 1 ]]; then
      zle reset-prompt
    fi
    if [[ ! -v ZFZF_ENABLE_DOT_DOTDOT ]]; then
        local -i ZFZF_ENABLE_DOT_DOTDOT=$ZFZF_DOT_DOTDOT
    fi
  fi

  # --- Configuration Options --- #
  local -i enable_color=${ZFZF_ENABLE_COLOR:-1}
  local -i enable_preview=${ZFZF_ENABLE_PREVIEW:-1}
  local -i dot_dotdot=${ZFZF_DOT_DOTDOT:-1}

  local -i enable_bat=${ZFZF_ENABLE_BAT:-2}
  local bat_path="${ZFZF_BAT_PATH:-}"

  local -i enable_exa=${ZFZF_ENABLE_EXA:-2}
  local exa_path="${ZFZF_EXA_PATH:-}"

  # --- Setup --- #
  local color="never"
  if [[ $enable_color -eq 1 ]]; then
    color="always"
  fi

  local -A cmds=()

  if [[ $enable_bat -ge 1 ]]; then
    cmds[bat]="${bat_path:-${commands[bat]:-}}"
    if [[ $enable_bat -eq 1 && -z "${cmds[bat]}" ]]; then
      echo >&2
      echo "Error: ZFZF_ENABLE_BAT is set but bat was not found in PATH" >&2
      if [[ $zle -eq 1 ]]; then
        zle reset-prompt
      fi
      return 1
    fi
    if [[ -z "${cmds[bat]:-}" ]]; then
      unset "cmds[bat]"
    fi
  fi

  if [[ $enable_exa -ge 1 ]]; then
    cmds[exa]="${exa_path:-${commands[exa]:-}}"
    if [[ $enable_exa -eq 1 && -z "${cmds[exa]}" ]]; then
      echo >&2
      echo "Error: ZFZF_ENABLE_EXA is set but exa was not found in PATH" >&2
      if [[ $zle -eq 1 ]]; then
        zle reset-prompt
      fi
      return 1
    fi
    if [[ -z "${cmds[exa]:-}" ]]; then
      unset "cmds[exa]"
    fi
  fi

  local -a awk_opts=()
  if [[ "${ZFZF_DOT_DOTDOT:-1}" -eq 1 ]]; then
    awk_opts+=(-v 'dot_dotdot=.\n..\n')
  fi
  if [[ $dirsonly -eq 1 ]]; then
    awk_opts+=(-v 'dirsonly=1')
  fi

  local input="${1:-}"
  local left=""
  local right=""
  if [[ -z "$input" && "$mode" =~ completion\|zle && -n "$LBUFFER$RBUFFER" ]]; then
    zmodload zsh/pcre
    if [[ -n "$LBUFFER" ]]; then
      # Split before word left-adjacent to the cursor
      pcre_compile -- '^(?U)((.*\s+)*)((\S|\\\s)+)$'
      if pcre_match -a mat -- "$LBUFFER"; then
        input="${mat[3]//(#m)\\/}"
        left="${LBUFFER:0:$((${#LBUFFER} - ${#input}))}"
      fi
    fi
    if [[ -n "$RBUFFER" ]]; then
      # Split after word right-adjacent to the cursor
      pcre_compile -- '^((\\\s|\S)+)((\s+.*)*)$'
      if pcre_match -a mat -- "$RBUFFER"; then
        input="${input}${mat[1]//(#m)\\/}"
        right="${mat[3]}"
      fi
    fi
  fi

  # --- Path Resolution --- #
  local path_orig="${input:-}"
  path_orig=${~path_orig}     # expand tilde
  path_orig="${(e)path_orig}" # expand variables
  # " <--- this quote is here to work around a vim zsh syntax highlighting bug

  local path_orig_absolute
  local relative="$PWD"
  if [[ "$path_orig" =~ ^/ ]]; then
    path_orig_absolute="$path_orig"
    relative="/"
  else
    path_orig_absolute="$(realpath -m "${path_orig:-.}")"
  fi

  # --- FZF Setup --- #
  local fzf_query=""
  if ! [[ -e "$path_orig_absolute" ]]; then
    fzf_query="$(basename "$path_orig")"
    path_orig="$(dirname "$path_orig")"
    path_orig_absolute="$(dirname "$path_orig_absolute")"
  fi

  if [[ "$mode" == "zle" ]]; then
    LBUFFER="${left}${path_orig}"
    zle reset-prompt
  fi

  local -a fzf_cmd=(
    /usr/bin/env fzf
      --reverse
      --ansi
      --print-query
      --cycle
      --height='50%'
      --header="$path_orig_absolute"
      --query="$fzf_query"
      --expect='ctrl-d,alt-return,ctrl-g,alt-P,alt-o,alt-i,alt-u,alt-U,alt-.,alt->'
      --bind='ctrl-o:replace-query'
  )

  if [[ $enable_preview -eq 1 ]]; then
    local preview_file
    if [[ ${+cmds[bat]} -eq 1 ]]; then
      preview_file="${cmds[bat]} --color='$color'"
    else
      preview_file="${commands[cat]}"
    fi

    local preview_dir
    if [[ ${+cmds[exa]} -eq 1 ]]; then
      preview_dir="${cmds[exa]} --tree --level=1 --color='$color'"
    else
      preview_dir="${commands[tree]} -L 1"
    fi

    local preview_other="stat '$f' 2>/dev/null"

    local -a fzf_preview=(
      'f="$(realpath -m "'"$path_orig_absolute"'/{}")";'
      'if [[ -d "$f" ]]; then'
        "$preview_dir"' "$f" 2>/dev/null;'
      'elif [[ -f "$f" ]]; then'
        "$preview_file"' "$f" 2>/dev/null;'
      'else'
        "$preview_other"' "$f" 2>/dev/null;'
      'fi'
    )

    fzf_cmd+=(
      --preview="bash -c '$fzf_preview'"
    )
  fi

  # --- FZF Run --- #
  local res
  res="$(
      "${commands[ls]}" -1Ap --color "$path_orig_absolute" \
      | "${commands[awk]}" "${awk_opts[@]}" '
          BEGIN { printf "%s", dot_dotdot }
          /\/$/ { dirs = dirs $0 "\n"; next }
          ! dirsonly { print }
          END { printf "%s", dirs }
        ' \
      | "${fzf_cmd[@]}")"

  # --- FZF Result Handling --- #
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
    "alt-u"|"alt->")
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

  # --- Final Result Handling --- #
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

  if [[ "$mode" == "zle" ]]; then
    LBUFFER="${left}${path_new}"
    RBUFFER="$right"
    zle reset-prompt
  fi

  if [[ "$key" =~ ^alt-[uUoP\>]$ || ( "$key" =~ ^alt-[i.]$ && ( ! -e "$path_new" || -d "$path_new" ) ) ]]; then
    zfzf "${opts[@]}" "$path_new"
    return
  fi
  if [[ "$mode" == "completion" ]]; then
    builtin compadd -UQqS '' -- "$path_new"
  fi
  if [[ "$mode" == "standalone" ]]; then
    echo "$path_new"
  fi
}

function disable-zfzf-tab() {
  if ! [[ -v _zfzf_tab && "${_zfzf_tab[enabled]}" -eq 1 ]]; then
    echo "disable-zfzf-tab: error: zfzf is not enabled" >&2
    return 1
  fi
  if [[ ! -v _zfzf_tab[_files_orig] ]]; then
    echo "disable-zfzf-tab: error: the original _files function was not found" >&2
    return 1
  fi
  if [[ ! -v _zfzf_tab[_path_files_orig] ]]; then
    echo "disable-zfzf-tab: error: the original _path_files function was not found" >&2
    return 1
  fi
  eval "${_zfzf_tab[_files_orig]}"
  eval "${_zfzf_tab[_path_files_orig]}"
  unset _zfzf_tab
}

function enable-zfzf-tab() {
  if [[ -v _zfzf_tab && "${_zfzf_tab[enabled]}" -eq 1 ]]; then
    echo "enable-zfzf-tab: error: zfzf tab already enabled" >&2
    return 1
  fi
  if [[ ! -v _zfzf_tab ]]; then
    declare -gA _zfzf_tab=()
  fi
  _zfzf_tab[enabled]=1
  _zfzf_tab[_files_orig]="$(declare -f _files)"
  _zfzf_tab[_path_files_orig]="$(declare -f _path_files)"
  function _files() {
    zfzf -c
  }
  function _path_files() {
    zfzf -c
  }
}

if [[ "${zsh_eval_context[*]}" == "toplevel" ]]; then
  zfzf "$@"
  exit $?
fi

function _zfzf() {
  zfzf -z "$@"
}

zle -N zfzf _zfzf

if [[ ! -v ZFZF_ZSH_BINDING || -n "${ZFZF_ZSH_BINDING}" ]]; then
  bindkey "${ZFZF_ZSH_BINDING:-"^[."}" zfzf
fi
