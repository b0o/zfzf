# zfzf [![version](https://img.shields.io/github/v/tag/b0o/zfzf?style=flat&color=yellow&label=version&sort=semver)](https://github.com/b0o/zfzf/releases) [![license: gpl-3.0-or-later](https://img.shields.io/github/license/b0o/zfzf?style=flat&color=green)](https://opensource.org/licenses/GPL-3.0)

> zsh + fzf

## Demo

![demonstration screencast](./assets/demo-01.gif)

## Install

```zsh
# zinit
zinit light b0o/zfzf
```

## Usage

By default, zfzf is mapped to `Alt-period`. If your cursor is adjacent to any
non-whitespace text when you trigger zfzf, it will attempt to interpret that
text as a path.

Please note that zfzf is still in the early stages of development. Its
behaviors, options, and key bindings are likely to change.

<!-- USAGE -->

```

zfzf v0.1.1

zfzf is a fzf-based file picker for zsh which allows you to easily navigate the
directory hierarchy and pick files using keybindings.

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

```

<!-- /USAGE -->

## TODO

- [ ] configurable options
  - [ ] key bindings
  - [ ] sorting
  - [ ] filtering
  - [x] color
  - [ ] fzf options

## License

<!-- LICENSE -->

&copy; 2021 Maddison Hellstrom

Released under the GNU General Public License, version 3.0 or later.

<!-- /LICENSE -->
