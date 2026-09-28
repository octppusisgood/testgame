# 《回响之城》AI 对接文档（HANDOVER）

> 本文件是给接手的 AI / 程序的项目交接指南。改动记录见 `修改记录_肉鸽模式.md`，未完成需求清单见桌面《肉鸽模式_未实现功能清单_最新.xlsx》。

---

## 1. 项目简介

- **引擎**：Godot 4.7.2（Windows 本地 winget 安装，控制台 exe 路径见 `launcher.ps1`）。
- **类型**：2.5D 俯视生存射击（3D 场景 + 2D UI），主题：丧尸末日 + 营地建造 + 肉鸽模式。
- **渲染器**：`gl_compatibility`（**不支持遮挡剔除**，性能优化须走距离剔除/LOD，见 §7）。
- **画面**：逻辑视口 640×360，`canvas_items` 拉伸到 1920×1080；**3D 实际按 `scaling_3d/scale=0.67` 渲染**（见 project.godot，勿还原成 1.0，性能差）。
- **语言**：GDScript（警告视为错误，未使用变量/类型推断警告都会编译失败），UI 全中文。
- **版本控制**：已 git init 于项目根目录。**规矩：每完成一批改动必须提交**（`.godot/` 已忽略）。

## 2. 运行 / 调试 / 测试

### 启动
- 玩家入口：`启动游戏.bat` → `launcher.ps1`（菜单：1 单人/联机、2 编辑器、3 自动化测试、5 测试模式）。
- 直接启动游戏场景：`Godot...console.exe --path . res://scenes3d/proto3d.tscn -- --test`（测试模式：资源全满）。

### 自动化测试（回归基线）
```bash
Godot_v4.7.2-stable_win64_console.exe --headless --path . res://tests/test_flow.tscn
```
**当前基线 = 4 项失败**（属历史遗留/未修，不算回归）：
1. 3D 近战命中正前方僵尸
2. 天灾阶段刷尸神
3. 近点瞄准子弹也按武器射程飞到底（方向射击）
4. 远点瞄准子弹按武器射程 45 米封顶
> 规矩：**改动后失败数不得超过基线 4 项**，多一项即是你的回归。

### 探针（临时测试脚本）
- 场景内脚本必须 `extends Node` + 配套 .tscn（`-s` 直接跑 SceneTree 脚本没有 autoload，GameState 找不到）。
- 用完**删除 .gd/.gd.uid/.tscn 三个文件**。写法见 `tests/test_flow.gd`。

### 游戏内调试键
- **F1** 帮助 · **F2** 隐藏/显示全部角色模型（渲染瓶颈 A/B 测试） · **F3** 性能悬浮窗 · **F4** 阴影开关 · **F5** 3D 分辨率循环 · **F12** 调试信息
- 测试模式专用：F6 灾变 / F7 下一阶段 / F8 尸神 / F9 昼夜 / F10 时间×10 / F11 尸潮

## 3. 架构与文件地图

| 文件 | 职责 |
|---|---|
| `scripts/game_state.gd` | **全局状态 autoload**（资源、武器、据点、信号、工人、玩家属性、空间哈希、结算）。改动核心都在这 |
| `scripts3d/proto3d.gd` | 主场景：城市生成、丧尸刷怪/人群渲染（MultiMesh crowd）、Boss 干扰磁场、性能剔除 |
| `scripts3d/hud3d.gd` | 全部 2D UI：HUD、交互菜单、背包、小地图宿主、Q 炮击圆盘 |
| `scripts3d/base_build3d.gd` | 据点建造管理 + **全部防御/生产设施类**（炮塔、迫击炮/火炮、信号塔、5 制作台、发电设备等） |
| `scripts3d/worker3d.gd` | 营地工人 / 随从 / 小队面板（J 键）/ 装备分配 |
| `scripts3d/zombie3d.gd` | 丧尸 AI、类型（普通/猎犬/狼蛛/Boss）、毒液 VenomShot |
| `scripts3d/fps_player.gd` | 玩家控制：移动、武器、技能、驾驶 |
| `scripts3d/minimap3d.gd` | 小地图 + 大地图（M 键，信号热力图「信号区」按钮） |
| `scripts3d/demolish3d.gd` | 拆除系统（Z 键，建筑/杂物） |
| `scripts3d/station3d.gd` | 信号塔共享模型构建器（玩家塔与旧基站同款） |
| `scripts3d/npc3d.gd` | 市民 NPC（招募、恐慌、转化） |
| `scripts3d/blocky_rig.gd` | SYNTY 角色装配（蒙皮/动画/LOD/预热缓存） |
| `scripts3d/vehicle3d.gd` | 载具驾驶/油耗/自动补给 |
| `tests/test_flow.gd` | 回归测试主文件 |

## 4. 核心系统要点

- **基地建造**：X 键任意处开菜单（信号塔任意位置可建，其余须据点半径内）。建造栏 4 类：防御/基建/制作/仓库。**5 制作台**：装备/药品/食品/弹药/异能（Fabricator 族，配方 `_recipes()`，数量滑条 1~999 连续制作，断料断电自动排队续做，齿轮常驻可见仅工作时转）。
- **信号网络**：据点信号圈（15+10×等级 m）+ 信号塔 400m 圈**接力**（BFS 连通）；孤立塔是独立区（有信号但不互通）。远程打击只能在**连通网络内**使用。判定统一走 `GameState.point_in_signal_coverage()`。
- **远程炮击（Q）**：按住 Q 出圆盘（迫击炮/火炮/圆心联合打击），炮弹按距离计算飞行时间，开火消耗对应炮弹（弹药加工台制造）。E 站炮边本地指挥不受信号限制；Q 远程离开信号区自动中断。
- **丧尸英雄位**：近处全模型（HORDE_HERO_CAP=22、30m），远处 MultiMesh 群演（全场 6 draw call）——**性能核心，勿全拉满**。
- **性能体系**：LOD（丧尸/NPC 28m/55m 冻结动画）、occludable 距离剔除 160m、掉落物 MultiMesh、人群移动 worker 线程、空间哈希（0.25s 重建）。**卡顿优先按 §7 排查**。

## 5. 开发规范（重要，别踩）

1. **每批改动**：写代码 → 探针/回归验证 → 追加 `修改记录_肉鸽模式.md` → git 提交。
2. **禁止**对源文件跑 `sed -i -n`/`head -N > file` 等截断命令（曾因此丢 9 个类，从 wire 日志抢救回来）。小改动用 Edit，整文件重写用 Write。
3. **`String(x)` 对 null 会抛错**（Godot 4.7）：遍历场景树找 `get("defense_type")` 这类可能为 null 的属性时，必须用 `str()`。
4. **CanvasLayer 下的 Control 锚定布局可能拿到 0 尺寸**（弹窗布局散架/按钮点不到）：直接显式铺满视口（参考 `worker3d._pin_full_rect`、hud3d StrikeDial 的 `_sync_rect`），输入必要时就 `_input` 直接判定。
5. 添加新防御设施：`game_state.BASE_DEFENSES` 加条目 + `base_build3d._spawn_defense` 加 match + 建造栏 `BUILD_CATEGORY_ITEMS` + 图标（BuildSlot `_draw_icon`）+ 操作员表 `OPERATOR_DEFS`（如需）。
6. UI 文案全中文；提示用 `GameState.notify()`，长提示用 HUD `_show_toast()`。
7. 探针脚本即写即删（.gd/.uid/.tscn 三件）；临时截图存 `user://` 并清理。
8. **渲染器是 gl_compatibility**：不要开遮挡剔除、不要加 MSAA/TAA、不要堆动态光源/阴影（全场只有 1 个方向光，阴影默认关，F4 可开）。

## 6. 已知的坑（历史教训）

- 资源条交互判定曾用 `String(node.get("defense_type"))` 空属性崩溃 → 全改 `str()`。
- J 面板/装备面板曾同层互相遮挡 → 面板层级 25/26 + 互斥显隐。
- 毒液/炮弹曾因宿主停跑而残留 → 一律自驱动实体（`_physics_process` + 寿命兜底）。
- 交互/拆除判定曾与视觉模型错位 → 统一「相机-鼠标射线」+ 模型实际 AABB。
- 方向光阴影在弱显卡上是致命伤 → 默认关，F4 切换。

## 7. 性能排查流程（godot-performance 技能已装在 `.kimi-code/skills/`）

卡顿时按序：F3 看 FPS/图元/绘制调用 → F2 隐藏角色对比（涨=渲染瓶颈）→ F5 降分辨率对比（涨=像素填充）→ F4 关阴影对比。
常用结论：本项目瓶颈≈**角色蒙皮+网格**（怪多时）与**全分辨率光栅化**（已 0.67）。

## 8. 当前状态

- 批次已到 **162**（制作台齿轮常驻）。功能全景看 `修改记录_肉鸽模式.md`；**未完成清单**（42 项，红/黄/绿标注）在桌面 xlsx——接手新需求优先从那里挑。
- 联机（LAN）网络层已有基础（remote_player3d / Network），但完整联机玩法未做。

## 9. 上手顺序建议

1. 读本文档 → 读 `修改记录_肉鸽模式.md` 最近 10 批 → 跑一遍回归确认 4 项基线。
2. 打开 xlsx 挑任务 → 开工前 `git commit` 基线 → 按 §5 规矩做 → 交回归+记录+提交。
3. 别动 §6 坑点已修复的判定链（信号/交互/拆除/炮弹自驱动），除非有新证据。
