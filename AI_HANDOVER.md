# 《回响之城》AI 交接文档（AI_HANDOVER）

> 目的：让另一个 AI（当前配置为 MiMo-V2.6-Pro）接手本项目时零上下文也能立刻干活。
> 本文档取代旧版（旧版只写到批次 162，已严重滞后）。**当前进度以「批次」为准，见下文 §4、§7。**
> 最后更新：2026-10-03（对应最新提交 `f62aa2d2` = 批次 253）。

---

## §1 项目概览

- **类型**：Godot 4.7.2 制作的 2.5D 斜俯视末日生存 / 割草 + 肉鸽（Roguelite）游戏，中文名《回响之城》。
- **渲染**：`gl_compatibility` 渲染器（**不支持遮挡剔除 / MSAA / TAA / 多动态光**，全程只有 1 个方向光，默认关阴影）。
- **分辨率**：视口 640×360，`canvas_items` 拉伸；3D 按 `scaling_3d/scale=0.67` 渲染（**勿改回 1.0**，性能会崩）。
- **语言**：GDScript（纯 GDScript，非 C#；`.uid` 文件依赖 Godot 4.7.x，低版本不兼容）。
- **警告策略**：GDScript 警告视为错误。
- **版本控制**：本地 git 仓库（**没有远程 remote**），每批一提交，`.godot/` 已忽略。提交信息格式：`批次 NNN：<改动摘要>`，命令 `git add -A && git -c user.name="dev" -c user.email="dev@local" commit -m "批次 NNN：..."`。

---

## §2 快速上手（环境 / 运行 / 测试 / 导出 / 部署）

### 环境
- Godot **4.7.2**（winget 安装，标准版非 .NET）。路径硬编码在 `launcher.ps1:3-4`：
  `%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64[_console].exe`
  （换机器要改这两行）。
- 导出模板在编辑器内「管理导出模板」下载，需 4.7.2.stable（web_release 等）。
- Python 3.13（`py` 启动器可用；`python` 是 Windows 商店占位符会报错，用 `py`）。

### 运行
- `启动游戏.bat` → `launcher.ps1` 菜单：1 游戏（`menu3d.tscn`）/ 2 编辑器 `-e` / 3 自动化测试 / 4 打开文件夹 / 5 测试模式（`proto3d.tscn -- --test`）/ 0 退出。
- **主流程**：主菜单 `menu3d.tscn` → 系统空间 `system_space3d.tscn`（局外：商城/基因库/强化仓/进城市）→ 城市 `proto3d.tscn`（局内）→ 撤离/结算 → 回系统空间。菜单已瘦身为**纯肉鸽入口**（无单人/联机按钮）。
- **测试模式**：`Godot..._console.exe --path . res://scenes3d/proto3d.tscn -- --test`（全资源解锁、调试键 F6~F11、炮弹无限、制造材料无上限）。

### 测试（回归）
```bash
Godot_v4.7.2-stable_win64_console.exe --headless --path . res://tests/test_flow.tscn
```
- **基线 = 4 项历史遗留失败**（3D 近战命中 / 天灾刷尸神 / 近点瞄准射程 / 远点瞄准 45m 封顶），其余约 390~450 项全过。**多一项失败即回归**。test_flow 的退出码 = 失败数。
- 探针写法：`extends Node`（或 `extends SceneTree`）+ 配套 `.tscn`，放 `tests/_tmp_xxx.gd` 或 `tests/probe_xxx.gd`，**用完删 `.gd` / `.gd.uid` / `.tscn` 三件**。裸跑 `-s` 无 autoload，autoload 用 `root.get_node("GameState")`。

### 导出（`export_presets.cfg`）
- preset.0 `Windows Desktop` → `dist/回响之城.exe`（embed_pck）。
- preset.1 `Web` → **`dist/web/test.html`**（产物全名为 `test.*`；`thread_support=true`，embed_pck）。
  - **Web 版文件名是 `test.*`**（`回响之城` 已改名为 `test`，见批次 235）。`<title>test</title>` 是导出后手动改的，**重新导出会变回「回响之城」**（标题来自 `project.godot` 的 `config/name`），需再手动改一次或改 config/name（改 config/name 会迁移存档路径，慎改）。
  - Web 端大小写敏感：曾有 2527 个 Synty 资源 `res://Assets/` 未改成 `res://assets/` 导致加载失败，已批量修。
- **瘦身导出**：Web pck 需排除未引用 Synty 资源。工具：
  - `tools_unused_refs.py`（两阶段引用闭包，生成 `synty_exclude.txt`）。
  - 把 `synty_exclude.txt` 里的文件移出工程到 `../_asset_stash/assets/Synty/`（**注意：目标已存在的同名文件是只读的，`os.replace` 会 PermissionError，先清目标只读**）。
  - 移出后跑**反向引用闭包**恢复被 uid 去重误删的资源（如 `Synty_Character_Collider.tres`：多个 `path=` 指向不同 pack，但 uid_cache 规范化到其中一个，正向闭包会漏）。用 `kimi`/`py` 脚本扫描 kept 文件的 `res://` 与 `uid://` 引用，从 `_asset_stash` 恢复缺失项。
  - 当前瘦身后 pck = **141MB**（未瘦身 806MB）。导出后 `gzip -9 -k -f` 压 pck/wasm/js 生成 `.gz`（Caddy 预压缩用）。

### 部署（线上 Web 版）
- 服务器：阿里云 `123.56.112.225`，Caddy 托管，部署路径 **`/home/web/www/game/`**。
- **认证用密钥，不是密码**：`scp -i /tmp/web_deploy_key root@123.56.112.225:/home/web/www/game/`（密钥文件在本机 `C:\Users\HUAWEI\AppData\Local\Temp\web_deploy_key`，建议备份，Temp 清理会丢）。
- 线上地址：**`https://hpa.volwave.cc/game/test.html`**（旧名 `回响之城.html` 已删）。
- 流程：导出 → `gzip -9 -k -f` 压 pck/wasm/js → `scp -i /tmp/web_deploy_key dist/web/* root@123.56.112.225:/home/web/www/game/` → `curl` 验证 `fileSizes`/`Last-Modified`。
- Caddy 已配 COOP/COEP + gzip 预压 + 静态资源 7 天缓存、html 无缓存。

---

## §3 架构与文件地图

| 路径 | 用途 |
|---|---|
| `scripts/game_state.gd` | **唯一 autoload（`GameState`）**：全局状态（资源/武器/据点/信号/玩家属性/结算/丧尸表 `ZOMBIE_TIERS` 等） |
| `scripts3d/` | 全部游戏逻辑，约 47 个 `.gd`。关键：`proto3d.gd`（主城市场景）、`hud3d.gd`（全部 UI）、`base_build3d.gd`（建造+设施+六台机器）、`zombie3d.gd`（丧尸 AI）、`fps_player.gd`（玩家）、`menu3d.gd`（主菜单）、`system_space3d.gd`（局外系统空间）、`minimap3d.gd`、`vehicle3d.gd`、`worker3d.gd`、`blocky_rig.gd`、`demolish3d.gd`、`building_interior3d.gd`、`military_base3d.gd`、`station3d.gd`、`npc3d.gd`、`police_*.gd`、`gas_pump3d.gd`、`engineer3d.gd`、`exit3d.gd`/`exit_structures3d.gd`、`network.gd`/`remote_player3d.gd`/`net_*.gd`（联机）等 |
| `scenes3d/` | 23 个 `.tscn`，与 scripts3d 对应。入口 `menu3d.tscn`（project.godot main_scene），主游戏 `proto3d.tscn`，`system_space3d.tscn`、`fps_player.tscn`、`hub3d.tscn` 等 |
| `assets/Synty/` | Synty 美术包（PolygonApocalypse/City/GangWarfare/Military/Shops/Animations/characters/items/weapons），已做过引用闭包瘦身（未引用部分移到 `../_asset_stash/`） |
| `assets/fonts/` | NotoSansCJKsc（Web 中文子集，655KB）+ `default_theme.tres`。**新增 UI 中文/图标若显示方框字需重新收集字符集子集化；避免用 emoji（字体子集不含）** |
| `tests/` | `test_flow.gd/.tscn`（回归主测试，约 21 段 `_test_*`）；联机探针 `net_host_probe`/`net_client_probe`；`md2docx.py` |
| `dist/` | 导出产物：`回响之城.exe`、`回响之城_肉鸽试玩版.exe`（915MB）、旧 `丧尸危机.exe`；`web/` 全是 `test.*` |
| 根目录文档 | `游戏框架设计.md`（v3 主设计 51KB）、`游戏数值配置.md`、`枪械数值配置.md`、`修改记录_肉鸽模式.md`（**2790 行 / 253 个批次，查任何功能实现脉络**）、`README_试玩版打包说明.txt` |
| 工具 | `tools_unused_refs.py`、`tools_export_slim.py`、`synty_exclude.txt`（排除清单 1.1MB）、`启动游戏.bat`、`launcher.ps1` |

---

## §4 当前进度（截至批次 253，2026-10-03）

**回归基线 4 项失败长期稳定，其余全过。** 主要系统均已落地：

- **肉鸽主轴**：关卡递进（能量场 1/2/3 → 尸王/尸皇/尸神，第 3 关通关胜利）；守关 Boss 核心护盾 + 专属掉落 + 干扰磁场；小能量点（无需营地即刷、城内随机、丧尸三段式 AI）；升级三选一 / 回响铭刻全屏面板（选前暂停）。
- **战斗/枪械**：9 种武器 + 右键技能；弹药口径制（每枪专属口径 × 普通/穿甲/燃烧）；枪械改装（升级/配件/弹种/异能槽）；双武器槽；手雷 G；用药 F；10 层枪械技能树；完美闪避子弹时间；子弹出射=枪口。
- **丧尸/怪物**：9 档 tier（普通 100HP → 尸神 3000HP）；蜘蛛毒液；MultiMesh 群演 + 英雄位 22；感染暴露值制（tier>2）。
- **建造/据点/营地**：统一建筑系统（占领/拆除/破坏，HP 1000 + 废墟）；底部分类建造栏；据点半径按建筑底座推导（8~20m）+ 付费扩建；营地有生命值、怪优先袭营。
- **电力**：发电机 50kW / 太阳能 / 风车 / 异能发电机（异能 1=30 电）；**已删蓄电池**，即发即用 + 市电兜底；小地图电力环。
- **信号系统**：玩家自建信号塔（400m BFS 接力）+ 雷达车；大地图信号热力图 +「信号区」按钮；右上角信号格图标；能量场 25m 干扰；无信号小地图降级显示。
- **制造台**：五台（装备/药品/食品/弹药/异能），制造材料统一货币，数量滑条 1~999 连续制作，缺料/缺电排队自恢复，齿轮动效。
- **载具**：约 17~19 款（民用车 + 坦克/APC/武装皮卡/火箭卡车/雷达车 + 直升机）；油耗三源自动补给；车斗建材 + 回营自动入库；Tab 载具管理；委派随从驾驶。
- **随从/工人/NPC**：招募、J 成员总览（多选批量指令）、操作员系统、建筑藏匿（整个人消失+冻结）、拾荒满包自动送回、12m 迎击丧尸。
- **UI/HUD**：魔兽式方格背包 + 立绘右栏 + 底部资源栏；顶部资源条；仓库面板；交互菜单鼠标/键盘；大地图；Esc 暂停菜单含完整操作说明。
- **局外/系统空间（2.5D）**：大厅（商城/基因库/强化仓/交易所）；SP 结算（撤离倍率信号驱动）；枪械技能树 + 身体属性跨局成长。

**最近批次（234~253）速览**：小地图无信号降级 → 电力环 → 制作台功耗降 → 发电机 50kW → 信号 UI 图标 → 食物单一化+自动进食 → 现金纯数值化 → 用药热键 F → 交互菜单鼠标 → 拾荒送回 → 随从迎击 → 小地图标记 → Esc 操作说明 → 营地半径按建筑 → 删蓄电池即发即用 → 异能发电机 → 拆除建材直入背包 → 车上挖取入车斗回营入库 → 随从进楼隐形修复 + 藏匿冻结。

> **批次号说明**：本文档「批次」= `修改记录_肉鸽模式.md` 的批次号 = git 提交信息的批次号（截至 253）。注意曾有两次 Web 相关提交被误标为「批次 234/235」（实际是 Web 瘦身与改名，与游戏功能的批次 234/235 重号），属历史笔误，不影响功能。

---

## §5 游戏设计摘要 + 路线图（详见 `游戏框架设计.md` v3）

- **概念**：双区域循环（系统空间局外 ⇄ 城querque局内），类《三角洲行动》。通关二选一：存活 100 天 或 击败追踪 Boss。
- **内环（单局）**：搜刮→建营→制造→武装→猎怪→救市民→挑能量场 Boss→发育→下一关。
- **外环（跨局）**：成绩结算系统点数 → 兑换图纸（永久）+ 大技能树（当局）→ 更强下一局。失败也是进度、无破产。
- **三层玩法**：种田层（营地/产线/市民）+ 割草层（刷怪/波次）+ 类魂层（Boss 闪避/完美闪避子弹时间）。
- **数值要点**：玩家 HP100/体力100/饱食100（每秒-0.35）；丧尸 100HP/10伤 → 尸神 3000HP/60伤；武器伤 13~200；资源上限 food50/meds50/ammo200/materials200/fuel60；营地等级上限 5。
- **路线图（核心待实现，见设计文档「跳过项」）**：能量场 Boss 战+关卡递进深化、武器配件/弹药系统完善、局内等级/异变、胜负判定、营地等级/防御建筑深化、追踪 Boss、系统空间商店闭环、联机模式。**数值全部留到调优阶段统一修订**（文档明列 10 处重复/分散定义需多处同步）。

---

## §6 开发规范 + 已知坑（务必遵守）

**每批流程**：改代码 → 探针/回归验证（不新增 FAIL）→ 追加 `修改记录_肉鸽模式.md` → git 提交 `批次 NNN：...`。

**红线（血的教训）**：
1. **禁止用 `sed -i -n` / `head -N >` 截断式批量编辑源文件**——已发生**两次**事故（批次 156 丢 9 个类；批次 249 砍掉 `base_build3d.gd` 尾部 2124 行/19 个类，靠 git 恢复）。用 Edit 工具做增量修改。
2. GDScript 坑：`String(null)` 崩溃 → 一律 `str()`；`mini()` 只收 2 参数；`Object.get()` 只收 1 参数（Dictionary.get 才有默认值）；禁 `a = b = c` 连等；SceneTree 脚本里类型推断不出要显式标注。
3. CanvasLayer 下 Control 锚定可能 0 尺寸 → 显式铺满（参考 `worker3d._pin_full_rect`、hud3d `_sync_rect`）。
4. 新增防御设施需在 **6 处注册**：`BASE_DEFENSES` + `base_build3d._spawn_defense` match + `BUILD_CATEGORY_ITEMS` + BuildSlot `_draw_icon` + `OPERATOR_DEFS`（如需）。
5. UI 全中文 + `GameState.notify()` / HUD `_show_toast()`；探针即写即删（三件）。
6. gl_compatibility 渲染禁忌：无遮挡剔除/MSAA/TAA/多动态光；方向光默认关阴影（F4 开）。
7. 历史坑：面板层级遮挡（25/26 互斥）、投射物必须自驱动+寿命兜底、交互/拆除统一「相机-鼠标射线 + AABB」、弱显卡阴影致命。

**性能排查**：F3 性能窗 → F2/F5/F4 对比；瓶颈=角色蒙皮+网格、全分辨率光栅化。`.kimi-code/skills/godot-performance` 技能可用。

---

## §7 当前状态 / 进行中 / 待办

**进行中（未完成，交接给下一个 AI 继续）**：
- **批次 254**：修复「驻扎随从在 J 面板看不到」——守营地/驻守/驾驶/藏匿四种驻扎态的卡片数。探针 `tests/probe_b254.gd/.tscn` 已写好（未提交），用于复现四种驻扎态的卡片数。**按规范完成后应删除探针三件并提交**。
- 未提交文件：`tests/probe_b254.gd`、`tests/probe_b254.tscn`（进行中）、`.zcodeignore`（另一工具的忽略清单，非游戏代码，可留可删）。

**已知遗留问题（散落记录，未修）**：
- `fps_player._update_occlusion` 在 occluder 释放时会报 `previously freed`（批次 31/32 记录，建议 `is_instance_valid` 防御）。
- `exit3d` 地图撤离点：完整代码但 `exit_open/pay_exit_cost` 未定义、场景未生成——**未接线死代码**（批次 213）。
- Web 瘦身移出的 Synty 资源，下次 Web 导出前需重新评估引用闭包（批次 49 提示）。
- 数值占位待调：塔上限、熟练度、感染扣血、武器升级费用等；随从成长/熟练度体系未做。

**测试基线约定**：test_flow 固定 4 项失败。若日后「顺手修好」某条，基线口径（4）需同步改本文件 + `修改记录`。

---

## §8 交接注意事项（给接手的 AI）

1. **先读**：本文件 → `游戏框架设计.md`（规划）→ `修改记录_肉鸽模式.md` 最近 10 批（现状脉络）→ 跑一次 `test_flow` 确认基线 4 项。
2. **改代码前**给用户简短方案、经批准再动手（用户偏好省 token、自己验证为主）；用户常开多个游戏窗口，改代码后要 `cmd //c taskkill //F //IM Godot_v4.7.2-stable_win64.exe` 再重启，否则他测的是旧版。
3. **每批**都写 `修改记录` + git 提交，编号递增（当前到 253，下一批 254 是进行中的随从 J 面板修复）。
4. **回归验证**每批必跑，不新增 FAIL。
5. **不要**做 `sed` 截断、不要改 `scaling_3d/scale`、不要动 `config/name`（会迁移存档）。
6. **部署**（更新线上 Web 版）见 §2「部署」，用 `/tmp/web_deploy_key`，产物名 `test.*`。
7. 未完成需求曾记录在桌面 `肉鸽模式_未实现功能清单_最新.xlsx`（42 项，**不在仓库内**，换机即失联）——待办以本文 §5 路线图 + §7 + `修改记录` 为准。
8. 用户会用**中文**下需求；回复用中文。当前会话模型已切为 **MiMo-V2.6-Pro**（`config.toml` 的 `default_model`），如需换回其他模型见 `~/.kimi-code/config.toml`。
