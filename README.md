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

<!-- USAGE -->
```
zfzf is a fzf-based file picker for zsh which allows you to easily navigate the
directory hierarchy and pick files using keybindings.

Configuration Options
  Environment Variable   Default Value

  ZFZF_NO_COLORS         0
    Disable colors.

  ZFZF_DOTDOT_DOT        1
    Don't display '.' and '..'.

  ZFZF_ZSH_BINDING       ^[. (Ctrl-.)
    Keybinding sequence to trigger zfzf. If set to the empty string, zfzf will
    not be bound. You can create a keybinding yourself by binding to the _zfzf
    function. See zshzle(1) for more information on key bindings.

Default Key Bindings

  return:            accept final
  alt-return:        accept final (return absolute path)
  esc:               escape
  ctrl-g:            escape (return absolute path)
  alt-o:             accept query
  ctrl-d:            accept query final
  alt-P              append query
  ctrl-o:            replace query
  alt-i:             descend into directory or accept file
  alt-.:             descend into directory or accept file
  alt-u:             ascend into parent directory
  alt->:             ascend into parent directory
  alt-U              ascend to next existing ancestor
```
<!-- /USAGE -->

## TODO

- [ ] configurable options
  - [ ] key bindings
  - [ ] sorting
  - [ ] filtering
  - [ ] color
  - [ ] fzf options

## License

<!-- LICENSE -->
&copy; 2021 Maddison Hellstrom

Released under the GNU General Public License, version 3.0 or later.
<!-- /LICENSE -->
