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
| 触摸板 | 可用(VoodooI2C 轮询模式,见下);手势、睡眠唤醒后的表现未充分测试 |
| 声音 | 可用(AppleALC,`alcid=13`:喇叭和耳机都正常) |
| 亮度滑块、Fn 亮度键 | 可用(见下;需要关闭"自动调节亮度") |
| 电池 | 可用(SMCBatteryManager + ECEnabler):电量、电压、放电电流、剩余时间、循环次数可读;电池序列号显示为占位符 `SerialNumber`;放电 10 分钟以上测过,剩余电量会正常下降;独显开着时功耗偏高 |
| 睡眠唤醒 | 命令触发的短睡眠(约 13 秒)和合盖睡眠各测过一次,驱动、触摸板、声音、亮度、双显卡唤醒后都正常;更长时间的睡眠未测 |
| 蓝牙 | 可用:控制器地址正常、状态 On,已配对并连接过设备(见下);长时间稳定性未测 |
| 摄像头 | 预览有画面;Photo Booth 拍照时会闪退(崩在 AMD 核显的 OpenGL 驱动里,和摄像头本身无关) |
| 有线网卡 | 配了 `RealtekRTL8111`,**未测试** |

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

### 触摸板

Synaptics I2C-HID 触摸板挂在 AMD I2C 控制器(`AMDI0010`)上,走 VoodooI2C,三个配置都已包含,要点:

- 启动参数 `-vi2c-force-polling`:触摸板的中断接在 AMD GPIO 上,用轮询绕开,代价是多占一点 CPU。
- `VoodooGPIO` 只当依赖库加载,其 `Info.plist` 里的匹配项已清空。原版会匹配 `AMDI0030`(AMD GPIO 控制器),导致开机约 30 秒后自动重启。
- `Kernel > Add` 顺序:`VoodooInput`、`VoodooGPIO`、`VoodooI2CServices`、`VoodooI2C`、`VoodooI2CHID`。依赖必须排在前面,缺 `VoodooInput` 则驱动能加载但光标不动。

### 声音与亮度

三个配置都已包含,要点:

- **声音**:ALC245,AppleALC 里对应 HP Omen 的是布局 13,启动参数 `alcid=13`。
- **亮度滑块**:NootedRed 只在笔记本 SMBIOS 下启用背光补丁,而这里用的是 `iMacPro1,1`,所以要加启动参数 `AMDBacklight=1`。
  另外需要 NootedRed 指南里的官方 `SSDT-PNLF`(`_UID` 为 0x13)和 `SSDT-ALS0`,以及 `SMCLightSensor.kext`、`BrightnessKeys.kext`。
- **Fn 亮度键**:DSDT 里 EC 的 `_Q10`/`_Q11` 只有在 `_OSI` 报告 Windows 版本时才向 LCD 发 0x87/0x86 通知,macOS 不报,所以键不起作用。
  用两条 ACPI 补丁把它们改名为 `XQ10`/`XQ11`,再由 `SSDT-BRTKEYS` 无条件发通知(源码在 `acpi-src/`;没有 `iasl` 的环境下手工汇编,建议自行用 `iasl` 编译对照)。
- 光感是伪造的固定读数,**请在系统设置 > 显示器里关闭"自动调节亮度"**,否则它会和手动调节打架,控制中心的滑块也可能是灰的(重启 `ControlCenter` 进程可恢复)。

### 电池

电池字段在 EC 里是 16 位宽,而 macOS 的 AppleACPIEC 只读 8 位,所以单靠 `SMCBatteryManager` 读不到。再加 `ECEnabler`(允许读取大于 1 字节的 EC 字段)就能不改 DSDT 读出电量。
拔掉电源后数据要过一小段时间才开始刷新。

### 蓝牙与摄像头

AX200 的蓝牙和 HP 摄像头都是主板上的内部 USB 设备,接在 `XHC0` 的第 4、第 3 号端口。DSDT 把这两个端口的 `_UPC` 写成"不可连接"(第一个字节为 0),macOS 就不会创建它们,设备也就看不见。

- 两条 ACPI 补丁(`Count 1`,只改 DSDT 里 `XHC0` 的 `PRT3.UPC1` 和 `PRT4._UPC`)把第一个字节改成 1,让端口出现。补丁的查找串依赖这份 DSDT 的字节布局(BIOS F.28),换 BIOS 版本要重新核对。
- `IntelBluetoothFirmware` 负责送固件,`IntelBTPatcher` 修 bluetoothd 的 LE 扫描问题,`BlueToolFixup` 让 macOS 12+ 接受第三方控制器。
- **`IntelBluetoothInjector` 在 Monterey 及更新版本上不能用**(项目 FAQ 明说),所以它在配置里被限制为 `MaxKernel 21.99.99`,只在旧系统加载。一开始它被启用时,蓝牙设备会一直卡在初始化状态。
- 另外写入了两个 NVRAM 变量 `bluetoothExternalDongleFailed`(`00`)和 `bluetoothInternalControllerInfo`(14 个零字节),来自上游 issue 评论。**它们是必须的**:对照实验里去掉这两个变量(并在开机时把已存的值删掉)后,固件虽然能加载,但 `bluetoothd` 把控制器当成 macOS 自带的内部芯片,表现为 `Address: NULL`、`State: Off`、`Chipset: BCM_4350C2`,蓝牙不工作。

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
4. **设置 Metal 白/黑名单(重要)。** 驱动让所有进程都可以使用独显的 Metal,而 Safari、Spotlight 等用 Metal 渲染的程序会因为
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
| SMCLightSensor / SMCBatteryManager / BrightnessKeys | 1.3.8 / 1.3.8 / 1.0.3 | acidanthera/VirtualSMC、acidanthera/BrightnessKeys |
| ECEnabler | 1.0.6 | averycblack/ECEnabler(原 1Revenger1) |
| IntelBluetoothFirmware / IntelBTPatcher / IntelBluetoothInjector | 2.4.0 | OpenIntelWireless/IntelBluetoothFirmware |
| BlueToolFixup | 2.7.2 | acidanthera/BrcmPatchRAM |
| SSDT-PNLF / SSDT-ALS0 | — | chefkiss.dev/Extras/SSDTs(NootedRed 官方指南) |
| NootedRed | 0.8.10 | ChefKissInc/NootedRed |
| ForgedInvariant | 1.5.0 | ChefKissInc/ForgedInvariant |
| SMCAMDProcessor / AMDRyzenCPUPowerManagement | 1.0.1 / 0.7.2 | trulyspinach/SMCAMDProcessor |
| itlwm | 2.3.0 | OpenIntelWireless/itlwm |
| IntelBluetoothFirmware / Injector | 2.4.0 | OpenIntelWireless/IntelBluetoothFirmware |
| RealtekRTL8111 | 2.4.2 | Mieze/RTL8111_driver_for_OS_X |
| VoodooI2C / HID / Synaptics(含 VoodooInput 1.1.6、VoodooGPIO、VoodooI2CServices) | 2.9.1 / 1.0 / 1.0 | VoodooI2C |
| AMFIPass | 1.4.1 | Dortania OpenCore-Legacy-Patcher 仓库的 payload |
| AppleMCEReporterDisabler | — | Dortania 指南要求(AMD + iMacPro1,1 + macOS 12.3 及以上) |

`itlwm.kext` 的 `Info.plist` 里没有预置 Wi-Fi 信息,网络在 HeliPort 里添加。
所有 kext 均为各项目自己发布的 Release 二进制。

## 许可证

本仓库自己的配置、脚本和文档使用 MIT 许可证(见 `LICENSE`)。`EFI/` 里的 OpenCore 和各 kext 保持它们各自的许可证,使用前请自行核对。
