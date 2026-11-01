# 推到 GitHub 之后

## 1 建仓库并推代码

```sh
cd /var/minis/workspace/PELite
git init -b main
git add .
git commit -m "PELite 2.3.1"
git remote add origin https://github.com/<你的账号>/pelite.git
git push -u origin main
```

## 2 先跑一次无签名构建，验证源码能编译

GitHub → Actions → `Build IPA` → Run workflow → 跑完下载 `PELite-unsigned` 这个 artifact。
这一步不碰证书，只验证 Xcode 工程与 Swift 代码有没有编译错。跑通了再走签名。

## 3 Secrets 清单

Settings → Secrets and variables → Actions → New repository secret

| 名称 | 取值方法 |
|---|---|
| `P12_BASE64` | `base64 -i cert.p12 \| pbcopy`（在 Mac 上执行，导出时设一个密码） |
| `P12_PASSWORD` | 导出 p12 时设的密码 |
| `MOBILEPROVISION_BASE64` | `base64 -i xxx.mobileprovision \| pbcopy` |
| `TEAM_ID` | 开发者后台右上角 Team ID，10 位字母数字 |
| `PROFILE_NAME` | 主 App 描述文件名（后台显示的 Name，不是 UUID） |
| `PROFILE_NAME_EXT` | 扩展用的描述文件（含 `*` 通配那条） |

描述文件必须包含三个扩展的 Bundle ID：

```
com.pe.skinlite
com.pe.skinlite.share
com.pe.skinlite.keyboard
com.pe.skinlite.noti
```

主 App 用独立描述文件，三个扩展可以用一条 `com.pe.skinlite.*` 通配描述文件。

## 4 生成签名版

Actions → `Build IPA` → Run workflow：

- `bundle_id`：填证书对应的前缀，默认 `com.pe.skinlite`
- `method`：企业签填 `enterprise`，自签填 `ad-hoc`（`ad-hoc` 必须把设备 UDID 加进描述文件）

跑完在 artifact 里下载 `PELite-ipa-<N>`，解压得到 `PELite.ipa`。

## 5 装到手机

| 场景 | 做法 |
|---|---|
| 企业签 | 上传 IPAserver 或自建分发页，`itms-services://?action=download-manifest&url=...` |
| 自签（免费账号） | Mac/Windows 上 Sideloadly / AltStore 拖入 IPA，7 天过期 |
| 越狱设备 | TrollStore 直接安装，不过期 |

自签需要先拿对方 UDID：让他用 Safari 打开一个描述文件页，装上后回连上报 UDID，你把这个 UDID 加进开发者后台的设备列表，重新生成描述文件再签。

## 6 已知坑

1. `exportArchive` 报 `No signing certificate "iOS Distribution" found` → 导入的 p12 里只有 Development 证书，换 Distribution 的
2. 报 `Provisioning profile doesn't include ...` → 描述文件没包含扩展的 Bundle ID，回开发者后台重建
3. 报 `requires a provisioning profile` → `export.plist` 里少写了某个扩展的 profile 映射，四个都要在
4. App 装上闪退 → 看 `build/archive.log` 里 `codesign` 段，通常是 entitlements 里的 App Group `group.com.pe.skinlite` 没在后台开通
5. 键盘扩展不记录 → 用户在设置里要开「允许完全访问」，引导文案已经写了
