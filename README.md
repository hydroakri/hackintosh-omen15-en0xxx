# hackintosh-omen15-en0xxx

HP OMEN 15(en0xxx/en1xxx 系列,AMD Ryzen + RTX 3060 Laptop)的 OpenCore EFI,macOS 15.8.1 Sequoia。
内屏用 AMD 核显 + NootedRed;独显用 [NullMoth NVIDIA 驱动](https://github.com/nullmoth/nvidia-macos-driver)(外接屏)。

> 这是一份个人机器的配置,不是通用 EFI。SMBIOS 是占位符,请自己生成,不要照搬别人的序列号。

## 机器

| | |
|---|---|
| 型号 | HP OMEN Laptop 15-en1xxx,BIOS AMI F.28 |
| CPU | AMD Ryzen 7 5800H(Cezanne,8C/16T) |
| 内屏 | AMD Radeon Vega(Cezanne,`1002:1638`),1080p 144Hz,内屏只接在核显上 |
| 独显 | NVIDIA RTX 3060 Laptop 6 GB(`10de:2520`),外接口走独显 |
| Wi-Fi / 蓝牙 | Intel AX200 |
| 有线网卡 | Realtek RTL8111 |
| 声卡 | Realtek ALC245 |
| 触摸板 | Synaptics,I2C-HID |
| SMBIOS | iMacPro1,1 |

BIOS:Above 4G Decoding 开,CSM 关(NullMoth 要求)。

## 状态

| | |
|---|---|
| 内屏显示与硬件加速 | 可用(AMD,显存 512 MB) |
| NVIDIA 独显 | 驱动可加载,Metal 3 / 6 GB;只验证了能识别和不崩溃,**稳定性、睡眠唤醒、外接屏长时间使用未充分测试** |
| Wi-Fi | 可用(`itlwm` + [HeliPort](https://github.com/OpenIntelWireless/HeliPort),`AirportItlwm` 扫不到网络) |
| 触摸板 | **不可用**(VoodooI2C 依赖的 VoodooGPIO 在这台 AMD 平台上会导致自动重启) |
| 有线网卡、蓝牙、音频、睡眠 | 配了对应 kext,**未测试** |

## EFI 与三个配置

`EFI/` 是同一份文件树,三个配置只差 `config.plist`,放在 `profiles/`:

| 配置 | 用途 | 与 `stable` 的区别 |
|---|---|---|
| `install` | 进入 Recovery / 安装 macOS | `NootedRed.kext` 关闭(它在 Recovery 环境下内屏黑屏,是上游已知问题) |
| `stable` | 装好系统后的日常使用,**独显被隐藏** | 基准 |
| `nvidia` | 使用 NVIDIA 驱动 | 启用 `AMFIPass`;`SSDT-NVIDIA-DISABLE` 关闭(不再隐藏独显);`IONDRVSupport` 加入 Kernel Block;boot-args 去掉 `-wegnoegpu`、加 `ipc_control_port_options=0` |

### 切换配置

```
tools/apply-profile.sh stable        # install | stable | nvidia
```

脚本把 `profiles/<名>.plist` 写成 `EFI/OC/config.plist`,并保留原 `config.plist` 里的 SMBIOS。
然后把 `EFI/` 同步到 ESP(U 盘或硬盘的 EFI 分区):

```
diskutil list                          # 找到 EFI 分区,例如 disk0s1
sudo diskutil mount disk0s1
sudo rsync -a --delete EFI/ /Volumes/EFI/EFI/
```

仓库里默认的 `EFI/OC/config.plist` 是 `install`。

### 第一次使用

1. 用 [GenSMBIOS](https://github.com/corpnewt/GenSMBIOS) 生成 `iMacPro1,1` 的序列号、MLB、UUID,ROM 填网卡 MAC 或任意 6 字节。
   写进 `EFI/OC/config.plist` 的 `PlatformInfo > Generic`(此后 `apply-profile.sh` 会保留它们)。
2. `tools/apply-profile.sh install`,同步到 U 盘,从 U 盘启动。

## 安装 macOS

1. 用 OpenCorePkg 自带的 `macrecovery` 下载 macOS 15 的恢复镜像,放到 U 盘。
2. 用 `install` 配置启动,进磁盘工具把目标盘抹成 APFS,安装。
3. 装完后把 EFI 放到目标盘自己的 ESP,改用 `stable` 配置启动。

## 安装 NVIDIA 驱动

前提:已能用 `stable` 进入桌面,BIOS 里 Above 4G 开、CSM 关,且你确认外接口接在独显上。

1. 切换到 `nvidia` 配置并同步到 ESP,重启。此时 `system_profiler SPDisplaysDataType` 应能看到 NVIDIA 卡(此时还显示 No Kext Loaded)。
2. 从上游 [Releases](https://github.com/nullmoth/nvidia-macos-driver/releases) 下载 `nullmoth-nvidia-<版本>.tar.gz`(测试过 2.3.3),
   对照 Release 里的 `SHA256SUMS.txt` 校验后安装。**不要把驱动 kext 再放进 `EFI/OC/Kexts`**:
   ```
   tar -xzf nullmoth-nvidia-*.tar.gz && cd pkgroot
   shasum -a 256 -c SHA256SUMS
   sudo ./install.sh
   sudo shutdown -r now
   ```
   首次会要求在「隐私与安全性」里允许扩展,允许后再重启一次;首次启动可能在 "PCI configuration end" 停一分钟左右。
3. 验证:
   ```
   kmutil showloaded --list-only | grep nullmoth     # 应有 NVRM、NVRMFB、NVRMAGDC、NVAccel 四行
   system_profiler SPDisplaysDataType
   ```
4. **设置 Metal 白/黑名单(重要)。** 驱动让所有进程都可以使用独显的 Metal,而 Safari 等基于 WebKit 的程序会因为
   NVK 的空指针(`nvk_UpdateDescriptorSets`)反复崩溃。把 `nvidia/nvmtl-allow.txt` 覆盖到驱动的允许列表:
   ```
   sudo cp nvidia/nvmtl-allow.txt /Library/GPUBundles/nvmtl-allow.txt
   sudo chmod 644 /Library/GPUBundles/nvmtl-allow.txt
   ```
   规则从上往下读,**第一条匹配的生效**:`-名字` 拒绝该进程使用独显设备,`*` 允许其余所有进程。
   所以拒绝行必须在 `*` 前面;`!WindowServer` 不要删,WindowServer 必须能读到这个文件。
   进程启动时才读取,改完重开应用即可。想只让指定程序用独显,把 `*` 去掉并逐行列出进程名。

卸载:`sudo ./uninstall.sh`(在 `pkgroot/` 里)。系统起不来时在启动参数里加 `-nvoff`,让驱动不接管这张卡。

此配置下的安全姿态:SIP 放宽(`csr-active-config=430A0000`)、Apple Secure Boot 关闭、AMFI 放宽,并加载未签名的内核扩展。

## 组件

| 组件 | 版本 | 来源 |
|---|---|---|
| OpenCore(DEBUG 构建) | 1.0.8 | acidanthera/OpenCorePkg |
| Lilu / VirtualSMC / AppleALC / VoodooPS2Controller | 1.7.2 / 1.3.8 / 1.9.8 / 2.3.7 | acidanthera |
| NootedRed | 0.8.10 | ChefKissInc/NootedRed |
| ForgedInvariant | 1.5.0 | ChefKissInc/ForgedInvariant |
| SMCAMDProcessor / AMDRyzenCPUPowerManagement | 1.0.1 / 0.7.2 | trulyspinach/SMCAMDProcessor |
| itlwm | 2.3.0 | OpenIntelWireless/itlwm |
| IntelBluetoothFirmware / Injector | 2.4.0 | OpenIntelWireless/IntelBluetoothFirmware |
| RealtekRTL8111 | 2.4.2 | Mieze/RTL8111_driver_for_OS_X |
| VoodooI2C / HID / Synaptics | 2.9.1 / 1.0 / 1.0 | VoodooI2C |
| AMFIPass | 1.4.1 | Dortania OpenCore-Legacy-Patcher 仓库的 payload |
| AppleMCEReporterDisabler | — | Dortania 指南要求(AMD + iMacPro1,1 + macOS 12.3 及以上) |

`itlwm.kext` 的 `Info.plist` 里没有预置 Wi-Fi 信息,网络在 HeliPort 里添加。
所有 kext 均为各项目自己发布的 Release 二进制,使用前请自行核对许可证。
