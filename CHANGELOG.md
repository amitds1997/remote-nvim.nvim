# Changelog

## [0.3.12](https://github.com/amitds1997/remote-nvim.nvim/compare/v0.3.11...v0.3.12) (2024-08-04)


### Bug Fixes

* **scripts:** Explicitly specify bash command to run scripts ([#156](https://github.com/amitds1997/remote-nvim.nvim/issues/156)) ([f837763](https://github.com/amitds1997/remote-nvim.nvim/commit/f83776310adc130e5084d1b7672f402dba4cc70e))

## [0.3.11](https://github.com/amitds1997/remote-nvim.nvim/compare/v0.3.10...v0.3.11) (2024-07-06)


### Bug Fixes

* **CI:** Fix broken test CI and deprecated actions ([931ed63](https://github.com/amitds1997/remote-nvim.nvim/commit/931ed63fee2f53339b22cb604af6ec4b643f3000))

## [0.3.10](https://github.com/amitds1997/remote-nvim.nvim/compare/v0.3.9...v0.3.10) (2024-06-08)


### Bug Fixes

* **provider:** Correctly handle upload dirs for non-standard configurations ([#142](https://github.com/amitds1997/remote-nvim.nvim/issues/142)) ([6927788](https://github.com/amitds1997/remote-nvim.nvim/commit/69277888c366440c01fd5cd5689867ce8b63f7a2))
* **provider:** use compression options correctly for user configuration ([#144](https://github.com/amitds1997/remote-nvim.nvim/issues/144)) ([a1ea159](https://github.com/amitds1997/remote-nvim.nvim/commit/a1ea1592770fe027849826f90212d99d231e935c))

## [0.3.9](https://github.com/amitds1997/remote-nvim.nvim/compare/v0.3.8...v0.3.9) (2024-05-26)


### Features

* support NVIM_APPNAME ([#139](https://github.com/amitds1997/remote-nvim.nvim/issues/139)) ([4460db7](https://github.com/amitds1997/remote-nvim.nvim/commit/4460db718b8fa39e40162fd0507ba2beebec8fa6))


### Bug Fixes

* **container:** handle container IDs correctly ([aadb0a0](https://github.com/amitds1997/remote-nvim.nvim/commit/aadb0a097ad0b3b1d8276fc082c2b8866bbf740d))

## [0.3.8](https://github.com/amitds1997/remote-nvim.nvim/compare/v0.3.7...v0.3.8) (2024-05-25)


### Bug Fixes

* **install:** handle arm releases better ([7f882cc](https://github.com/amitds1997/remote-nvim.nvim/commit/7f882ccd02f6efe5f54a6a05eebc165eaca89476))

## [0.3.7](https://github.com/amitds1997/remote-nvim.nvim/compare/v0.3.6...v0.3.7) (2024-05-25)


### Bug Fixes

* devpod opts adding and container launch ([a6b741b](https://github.com/amitds1997/remote-nvim.nvim/commit/a6b741bd78c93a21cc57b2e536c58acaef3d3a85))
* handle docker wrappers well ([322e992](https://github.com/amitds1997/remote-nvim.nvim/commit/322e992a8f06b9f54fd60738a500dd7cb73a4b45))
* handle not adding ssh config path to existing devpod workspaces ([ff04924](https://github.com/amitds1997/remote-nvim.nvim/commit/ff04924d4d5243982bf1ccb42dd9f104fb8ef8e0))
* improve directory creation ([#134](https://github.com/amitds1997/remote-nvim.nvim/issues/134)) ([86e8fc5](https://github.com/amitds1997/remote-nvim.nvim/commit/86e8fc553826d5ac521f158ea745c9d30aba8ce3))
* **install:** handle new URIs for macOS releases ([eb76078](https://github.com/amitds1997/remote-nvim.nvim/commit/eb7607843ebc7accfcce1d24054cee35f4081333))
* macos installation ([#133](https://github.com/amitds1997/remote-nvim.nvim/issues/133)) ([1217416](https://github.com/amitds1997/remote-nvim.nvim/commit/1217416704a21bcfa79612e7f63ed28ad43e0040))

## [0.3.6](https://github.com/amitds1997/remote-nvim.nvim/compare/v0.3.5...v0.3.6) (2024-05-22)


### Features

* **devcontainer+docker:** Add devcontainer and docker support ([#66](https://github.com/amitds1997/remote-nvim.nvim/issues/66)) ([7e8b322](https://github.com/amitds1997/remote-nvim.nvim/commit/7e8b322fdd14bffd0e7b6032dbdd5e43057668b8))


### Bug Fixes

* **devpod:** check devpod/docker executable is available ([f63fae1](https://github.com/amitds1997/remote-nvim.nvim/commit/f63fae11d905fc20b36427030e2b7dcca55be84e))

## [0.3.5](https://github.com/amitds1997/remote-nvim.nvim/compare/v0.3.4...v0.3.5) (2024-05-08)


### Features

* **remote:** add flag to indicate if the server is launched by remote-neovim ([#125](https://github.com/amitds1997/remote-nvim.nvim/issues/125)) ([62cad51](https://github.com/amitds1997/remote-nvim.nvim/commit/62cad51db7e1bf75162980ca39cbaf740c0410d3))


### Bug Fixes

* **gui:** do not show borders with GUI Neovim ([658a89a](https://github.com/amitds1997/remote-nvim.nvim/commit/658a89a81fa68e95bfdc05214f688d454d9708a2))
* **ui:** Gracefully handle scenario where we reconnect to remote server ([1db2ff4](https://github.com/amitds1997/remote-nvim.nvim/commit/1db2ff4a27b28f93c068f84570fbe4a071250e55))

## [0.3.4](https://github.com/amitds1997/remote-nvim.nvim/compare/v0.3.3...v0.3.4) (2024-05-08)


### Bug Fixes

* **provider:** set install method correctly ([c0ddaa4](https://github.com/amitds1997/remote-nvim.nvim/commit/c0ddaa46fe8ace17e9a5428d6c15d51e1f6cdb1d))

## [0.3.3](https://github.com/amitds1997/remote-nvim.nvim/compare/v0.3.2...v0.3.3) (2024-05-08)


### Features

* **provider:** Always allow remote Neovim installation as an option (if available) ([#119](https://github.com/amitds1997/remote-nvim.nvim/issues/119)) ([2044ac4](https://github.com/amitds1997/remote-nvim.nvim/commit/2044ac4bdc9786255ef6cad2c6dde01a6b31b944))

## [0.3.2](https://github.com/amitds1997/remote-nvim.nvim/compare/v0.3.1...v0.3.2) (2024-04-28)


### Bug Fixes

* **offline:** fetch correct offline versions ([1ae25e7](https://github.com/amitds1997/remote-nvim.nvim/commit/1ae25e79e9877f5914da88a7d66865e95831d704))
* **offline:** fix breaking tests ([bbd82d6](https://github.com/amitds1997/remote-nvim.nvim/commit/bbd82d672f286731174c1d67b82bf508eed87770))

## [0.3.1](https://github.com/amitds1997/remote-nvim.nvim/compare/v0.3.0...v0.3.1) (2024-04-27)


### Bug Fixes

* **ci:** Fix file to update with the correct release ([4a4251d](https://github.com/amitds1997/remote-nvim.nvim/commit/4a4251d6d6051a9eb41bf6eecf5dc06cf50263ce))

## [0.3.0](https://github.com/amitds1997/remote-nvim.nvim/compare/v0.2.7...v0.3.0) (2024-04-25)


### ⚠ BREAKING CHANGES

* **install:** Support source and system installed Neovim ([#93](https://github.com/amitds1997/remote-nvim.nvim/issues/93))

### Features

* **install:** Support source and system installed Neovim ([#93](https://github.com/amitds1997/remote-nvim.nvim/issues/93)) ([c4455b5](https://github.com/amitds1997/remote-nvim.nvim/commit/c4455b50ab722e85e4663d89e27dbe0c28844b5f))
* support all other OSes through alternate install methods ([#113](https://github.com/amitds1997/remote-nvim.nvim/issues/113)) ([14c202c](https://github.com/amitds1997/remote-nvim.nvim/commit/14c202ca8cd7541b486d4e30a9bcdebbb2cdbef8))

## [0.2.7](https://github.com/amitds1997/remote-nvim.nvim/compare/v0.2.6...v0.2.7) (2024-04-17)


### Bug Fixes

* **ui:** resize popup window with nvim resize ([#108](https://github.com/amitds1997/remote-nvim.nvim/issues/108)) ([fd0f74a](https://github.com/amitds1997/remote-nvim.nvim/commit/fd0f74a8ce0ea479887b86fbd3f7957473dceecf))

## [0.2.6](https://github.com/amitds1997/remote-nvim.nvim/compare/v0.2.5...v0.2.6) (2024-04-14)


### Features

* **ssh:** support passphrase input in remote neovim ([#104](https://github.com/amitds1997/remote-nvim.nvim/issues/104)) ([fde45f9](https://github.com/amitds1997/remote-nvim.nvim/commit/fde45f94232209797b32b7c0a5789b11bf5e406b)), closes [#103](https://github.com/amitds1997/remote-nvim.nvim/issues/103)

## [0.2.5](https://github.com/amitds1997/remote-nvim.nvim/compare/v0.2.4...v0.2.5) (2024-04-10)


### Bug Fixes

* **ssh:** use `--disable-copyfile` only on macOS when compressing ([#101](https://github.com/amitds1997/remote-nvim.nvim/issues/101)) ([7472c45](https://github.com/amitds1997/remote-nvim.nvim/commit/7472c452dad2682ce3061e3e23e7d304905afe20))

## [0.2.4](https://github.com/amitds1997/remote-nvim.nvim/compare/v0.2.3...v0.2.4) (2024-03-24)


### Features

* **config:** add more default password prompt matchers ([#98](https://github.com/amitds1997/remote-nvim.nvim/issues/98)) ([cfc7bd6](https://github.com/amitds1997/remote-nvim.nvim/commit/cfc7bd63d7f36c5cbef11fac7cb9b8f388eac7ec))


### Bug Fixes

* **ssh:** Correctly handle path expansion for Include directive ([#96](https://github.com/amitds1997/remote-nvim.nvim/issues/96)) ([de2004d](https://github.com/amitds1997/remote-nvim.nvim/commit/de2004d8af5e714f7744ecb0c267bbd832f17ca7))

## [0.2.3](https://github.com/amitds1997/remote-nvim.nvim/compare/v0.2.2...v0.2.3) (2024-02-14)


### Features

* support copying other neovim directories to remote ([#88](https://github.com/amitds1997/remote-nvim.nvim/issues/88)) ([8135d46](https://github.com/amitds1997/remote-nvim.nvim/commit/8135d462047297e236d38f1e6d9eb4b506ca2154))

## [0.2.1](https://github.com/amitds1997/remote-nvim.nvim/compare/v0.2.0...v0.2.1) (2024-01-31)


### Features

* add offline mode ([#81](https://github.com/amitds1997/remote-nvim.nvim/issues/81)) ([a978017](https://github.com/amitds1997/remote-nvim.nvim/commit/a978017cc6878c862bb830334b3c51ff6e535a05))

## [0.2.0](https://github.com/amitds1997/remote-nvim.nvim/compare/v0.1.3...v0.2.0) (2024-01-27)


### ⚠ BREAKING CHANGES

* improve version detection and bump minimum neovim version to 0.9.0

### Features

* add drop down when there are multiple active session with :RemoteStop ([2d715c1](https://github.com/amitds1997/remote-nvim.nvim/commit/2d715c1a960bf3a72844e4ebaac60fc467030955))
* add highlight groups and show correct pane when client is not launched ([3ae2ffb](https://github.com/amitds1997/remote-nvim.nvim/commit/3ae2ffb8fb3854b2c389d3bb9318588ef77264a6))
* add host and connection details to session info ([25aa5d9](https://github.com/amitds1997/remote-nvim.nvim/commit/25aa5d9e595760be851de77e3714545f19e3d78b))
* add keymap help window ([446d16a](https://github.com/amitds1997/remote-nvim.nvim/commit/446d16a06757585ff566a11b3c38cde41d9fe3fd))
* add session info pane ([bf2f93a](https://github.com/amitds1997/remote-nvim.nvim/commit/bf2f93a822f4bf713d3f47ad5e74307eae2ae987))
* improve :RemoteStart behaviour ([245e6e7](https://github.com/amitds1997/remote-nvim.nvim/commit/245e6e7ed315c857a9f0aa110f17c9b12e821fe0))
* improve manual ssh input and remote connection check ([b03a196](https://github.com/amitds1997/remote-nvim.nvim/commit/b03a196e236a3f28243a4dcdc267a32f3f5c124c))
* improve version detection and bump minimum neovim version to 0.9.0 ([c4c3c44](https://github.com/amitds1997/remote-nvim.nvim/commit/c4c3c44b666abf5e1195483a2c3a09f86f5311ba))
* set correct defaults for progressview window ([f87e418](https://github.com/amitds1997/remote-nvim.nvim/commit/f87e418c0f96eec5ee309ac5e24d9e299dac49ef))
* switch to table opts and add logviewer ([2fb2707](https://github.com/amitds1997/remote-nvim.nvim/commit/2fb2707e6677c786cec554c63248cad97d6fd54f))


### Bug Fixes

* better tracebacks and correct schedule wrapping ([d3093cd](https://github.com/amitds1997/remote-nvim.nvim/commit/d3093cd30d5b372d577faf81247b7498bdcabd67))
* correct color coding when we cleanup remote ([ef4bad6](https://github.com/amitds1997/remote-nvim.nvim/commit/ef4bad6d774480ae9af998fcdecaafd2312edb2c))
* correct neovim version checks ([690a835](https://github.com/amitds1997/remote-nvim.nvim/commit/690a835cc247be8dc4c9b6d23b3aa386047109b4))
* correctly close remote session even if changes are pending ([330f90f](https://github.com/amitds1997/remote-nvim.nvim/commit/330f90f88c223206fb0af4e1979fa4b6a96aaef7))
* format markdown files and add pre-commit selene hook ([#72](https://github.com/amitds1997/remote-nvim.nvim/issues/72)) ([0a7bd8f](https://github.com/amitds1997/remote-nvim.nvim/commit/0a7bd8ff05834899961d165654b6556f61a35129))
* multiple popups do not work together and write detailed traceback ([271a77c](https://github.com/amitds1997/remote-nvim.nvim/commit/271a77cbd86a121a1a53cf3f5bfe2d4088fba261))
* squash recursive .remote-nvim bug ([39df787](https://github.com/amitds1997/remote-nvim.nvim/commit/39df787f1f85eb61f9ac309e685af99b3b5d5b18))
* **telescope:** correct finder name in the preview window for existing workspaces ([75475bf](https://github.com/amitds1997/remote-nvim.nvim/commit/75475bff57b20a9b8ee999828d8093a949b6feb8))
* use dynamic uv definition to handle deprecated loop ([14d6e07](https://github.com/amitds1997/remote-nvim.nvim/commit/14d6e0765b09cd028dbdd5f513de68b52e7b367a))

## [0.1.3](https://github.com/amitds1997/remote-nvim.nvim/compare/v0.1.2...v0.1.3) (2023-11-02)


### Bug Fixes

* **notification:** Notification does not go away if server is already running ([#61](https://github.com/amitds1997/remote-nvim.nvim/issues/61)) ([4e65b1b](https://github.com/amitds1997/remote-nvim.nvim/commit/4e65b1bfa4d0aa05bb6a134af8091ca982e71492))
* **provider:** Fix hostname parsing in connection options ([#64](https://github.com/amitds1997/remote-nvim.nvim/issues/64)) ([e57a2f8](https://github.com/amitds1997/remote-nvim.nvim/commit/e57a2f890727bd77af096487826680a594766e1f))

## [0.1.2](https://github.com/amitds1997/remote-nvim.nvim/compare/v0.1.1...v0.1.2) (2023-10-29)


### Bug Fixes

* **health:** Checkhealth was broken due to an incorrect call ([#59](https://github.com/amitds1997/remote-nvim.nvim/issues/59)) ([5c56a70](https://github.com/amitds1997/remote-nvim.nvim/commit/5c56a700028b0f6e18810d86f218c8abb14b8842))

## [0.1.1](https://github.com/amitds1997/remote-nvim.nvim/compare/v0.1.0...v0.1.1) (2023-09-28)


### Bug Fixes

* determine user's home directory on remote robustly ([#49](https://github.com/amitds1997/remote-nvim.nvim/issues/49)) ([f8db042](https://github.com/amitds1997/remote-nvim.nvim/commit/f8db0420e6d28d93cd23efd7fa6e1b5fdbb726ad))
* **provider:** fix E5560 when calling vim.ui.select() ([#53](https://github.com/amitds1997/remote-nvim.nvim/issues/53)) ([f299fb1](https://github.com/amitds1997/remote-nvim.nvim/commit/f299fb14e49cf0060911016290742bae847e1dc7)), closes [#52](https://github.com/amitds1997/remote-nvim.nvim/issues/52)

## [0.1.0](https://github.com/amitds1997/remote-nvim.nvim/compare/v0.0.1...v0.1.0) (2023-09-24)


### Bug Fixes

* handle when ui.select is synchronous ([#38](https://github.com/amitds1997/remote-nvim.nvim/issues/38)) ([da88176](https://github.com/amitds1997/remote-nvim.nvim/commit/da881769f9136620e6ce4691e4bfb953d9fc6361))
* remove deprecated function call ([#35](https://github.com/amitds1997/remote-nvim.nvim/issues/35)) ([6be08bd](https://github.com/amitds1997/remote-nvim.nvim/commit/6be08bd6ae90faebea0ceb59059d0ad182ed6e16))


### Miscellaneous Chores

* release 0.1.0 ([8cf267e](https://github.com/amitds1997/remote-nvim.nvim/commit/8cf267e19b27546fa63ee99c6ab97fe3f4068fe4))

## 0.0.1 (2023-08-09)


### ⚠ BREAKING CHANGES

* **remote-nvim:** Refactored the entire code base to make it more manageable and extendable

### Features

* Add logging ([#13](https://github.com/amitds1997/remote-nvim.nvim/issues/13)) ([51bc0a7](https://github.com/amitds1997/remote-nvim.nvim/commit/51bc0a7c263c58ea4a17868d2b3afaef16b936f3))
* add Neovim user commands ([#19](https://github.com/amitds1997/remote-nvim.nvim/issues/19)) ([ec8d68e](https://github.com/amitds1997/remote-nvim.nvim/commit/ec8d68ecb308301326b2fcfff284d6c987ef3d37))
* added progress reporter ([#15](https://github.com/amitds1997/remote-nvim.nvim/issues/15)) ([84d952a](https://github.com/amitds1997/remote-nvim.nvim/commit/84d952af68de2991af7c30cd5742bebc1c9bd661))
* configure logger to write only to file ([#14](https://github.com/amitds1997/remote-nvim.nvim/issues/14)) ([37bfa49](https://github.com/amitds1997/remote-nvim.nvim/commit/37bfa49b51e326a418ec3b5c6ffa9ef1a24367a6))
* Improve user experience ([#17](https://github.com/amitds1997/remote-nvim.nvim/issues/17)) ([14cd3c6](https://github.com/amitds1997/remote-nvim.nvim/commit/14cd3c607b98bd35ddb8690e8a21c4a42dba0d45))
* **install-nvim:** Added installation script for Neovim ([7fdabc1](https://github.com/amitds1997/remote-nvim.nvim/commit/7fdabc1153c0965539b8d41dcff4cc8b2957c084))
* **logging:** Add logger ([#8](https://github.com/amitds1997/remote-nvim.nvim/issues/8)) ([777258a](https://github.com/amitds1997/remote-nvim.nvim/commit/777258aa951ab39bad8ea83075569ecdeb976d41))
* **remote-login:** Save password for session after first input ([#7](https://github.com/amitds1997/remote-nvim.nvim/issues/7)) ([90490fa](https://github.com/amitds1997/remote-nvim.nvim/commit/90490faebe7de5cbeabadb23ae13216cb17b5037))
* **remote-nvim-ssh:** Add capability to SSH into remote server ([c4da117](https://github.com/amitds1997/remote-nvim.nvim/commit/c4da1177d1517b577e55e9a8f49b1f22edb4bfd5))
* **remote-nvim-ssh:** Add SSHJob and SSHSession ([d6b185f](https://github.com/amitds1997/remote-nvim.nvim/commit/d6b185f79fbb292344ada4faa4a222e7ae969af4))
* **remote-nvim-ssh:** Capture hostname and ssh options ([34372bb](https://github.com/amitds1997/remote-nvim.nvim/commit/34372bbd90f2987d785fe5662a02e57c39a66f23))
* **remote-nvim-ssh:** Initial commit ([31d4e38](https://github.com/amitds1997/remote-nvim.nvim/commit/31d4e38fa6ea4373f694a871449252e5ab5ccd57))
* **remote-nvim-ssh:** Integrate SSH session with Telescope ([a871ad4](https://github.com/amitds1997/remote-nvim.nvim/commit/a871ad478311cf8f3482f910a50978cc5879ebfc))
* **remote-nvim:** Add remote host configuration tracking ([#4](https://github.com/amitds1997/remote-nvim.nvim/issues/4)) ([c7ae2e4](https://github.com/amitds1997/remote-nvim.nvim/commit/c7ae2e416962b10c850d38d42f28437bf05de83b))
* **remote-nvim:** Add SCP support and prepare for Neovim ([b2fe1d7](https://github.com/amitds1997/remote-nvim.nvim/commit/b2fe1d79b80623c9a37a16d3fdfca1b2d3234f27))
* **remote-nvim:** Make SSH jobs async ([#1](https://github.com/amitds1997/remote-nvim.nvim/issues/1)) ([ea0ea19](https://github.com/amitds1997/remote-nvim.nvim/commit/ea0ea1920aabd990f149341c485196526a4c9d74))
* **ssh-login:** Add support for verifying new host ([#9](https://github.com/amitds1997/remote-nvim.nvim/issues/9)) ([481873a](https://github.com/amitds1997/remote-nvim.nvim/commit/481873adb762ab888dc8a93ade81804422be3b9f))


### Bug Fixes

* broken docs CI ([#22](https://github.com/amitds1997/remote-nvim.nvim/issues/22)) ([bfd2b74](https://github.com/amitds1997/remote-nvim.nvim/commit/bfd2b74b9244eb5d3c5f22cb821f1cf944c981da))
* broken port forwarding handling ([#23](https://github.com/amitds1997/remote-nvim.nvim/issues/23)) ([f4b3b84](https://github.com/amitds1997/remote-nvim.nvim/commit/f4b3b844ad11100c953501f464cc64adc8c7e22b))
* launch of client while server is still is unavailable ([#18](https://github.com/amitds1997/remote-nvim.nvim/issues/18)) ([e8a4c55](https://github.com/amitds1997/remote-nvim.nvim/commit/e8a4c551d062b8b720db674a0380c31bd89e01a0))
* nasty little index issue leading to hanging SSH jobs ([#25](https://github.com/amitds1997/remote-nvim.nvim/issues/25)) ([0202949](https://github.com/amitds1997/remote-nvim.nvim/commit/0202949e81e8560c2d83f506af100833caafdc78))
* **remote-nvim-ssh:** Fix last line bug in connection verification ([f96037a](https://github.com/amitds1997/remote-nvim.nvim/commit/f96037a9f1a3500e4e2d41b6ca9b7516e4df01f6))
* **remote-nvim:** Make ssh options parsing more robust ([da1f4ed](https://github.com/amitds1997/remote-nvim.nvim/commit/da1f4ed62fca078aec4347fa1b0e8ff17b4ce8ca))
* **remote-setup:** Fix port forwarding starting before setup ([#6](https://github.com/amitds1997/remote-nvim.nvim/issues/6)) ([b966235](https://github.com/amitds1997/remote-nvim.nvim/commit/b9662351c23a279969935a4127c0826bfc02d7f3))
* **ssh:** Remove `ssh` prefix, if exits in options ([2cdea34](https://github.com/amitds1997/remote-nvim.nvim/commit/2cdea348af52eb6e04987f6f1b73520aa384ffc9))
* **ssh:** Shellescape commands to be run over SSH ([95615e4](https://github.com/amitds1997/remote-nvim.nvim/commit/95615e40746a01a5492d729aac363e1e855fd078))
* upload and download args ([#24](https://github.com/amitds1997/remote-nvim.nvim/issues/24)) ([8b16fdb](https://github.com/amitds1997/remote-nvim.nvim/commit/8b16fdb9ca71c9df321d5df683a88e4a37f87987))


### Performance Improvements

* Simplify checks ([#16](https://github.com/amitds1997/remote-nvim.nvim/issues/16)) ([0e66294](https://github.com/amitds1997/remote-nvim.nvim/commit/0e66294b671ae9568ea6d36e1ba7f68434e9995a))


### Miscellaneous Chores

* release 0.0.1 ([5d1494d](https://github.com/amitds1997/remote-nvim.nvim/commit/5d1494dd9997e31fadbf0f7aa4a5509ae0e48034))


### Code Refactoring

* **remote-nvim:** Refactor existing code to abstract away providers ([#12](https://github.com/amitds1997/remote-nvim.nvim/issues/12)) ([d7fd18c](https://github.com/amitds1997/remote-nvim.nvim/commit/d7fd18c757b6ea0775dc79b45243d25ace58ba9a))
