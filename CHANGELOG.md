# Changelog

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
