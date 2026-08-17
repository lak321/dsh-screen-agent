# DSH Screen Agent — 屏幕识别 / UI 自动化 / 画图

给 [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness) 增加**桌面与网页自动化**能力：

- 📸 **截图**：全屏/多显示器截图
- 🔍 **OCR 识别**：Windows 内置 OCR（本地、无网络），提取文字 + 精确像素坐标
- 🖱️ **鼠标控制**：点击/双击/右键/拖拽（多显示器副屏负坐标支持）
- ⌨️ **键盘控制**：中文安全打字（剪贴板+Ctrl+V）、SendKeys 按键、窗口激活
- 🎨 **画图能力**：操作 Windows 画图工具绘制图形（经过实战打磨：鼠标加速度补偿、画布定位、曲线绘制）

纯 **Host 插件**，Windows 平台，零第三方依赖（PowerShell + user32 / WinRT OCR）。

## 功能

### 屏幕识别
- `capture`：全屏（含副屏）截图 → PNG + base64，截图存 `~/.dsh/screenshots/`
- `ocr`：Windows OCR 输出每行文字 + 中心像素坐标（可直接用于鼠标点击）

### UI 自动化
| 操作 | 说明 |
|---|---|
| `click / double / right` | 鼠标左键/双击/右键点击（x,y 像素坐标） |
| `drag` | 按住拖动（含 Shift 拖拽：画正圆等） |
| `type` | 输入文字（中文安全：剪贴板 + Ctrl+V） |
| `key` | 按键（SendKeys 语法，如 `^c`、`{ENTER}`、`{ESC}`） |
| `activate` | 按窗口标题激活窗口 |

### 画图（Paint）
- **画布定位**：UIA 确认画布控件位置（会漂移），内容画在控件中心
- **画笔大小**：画布左侧滑块（UIA RangeValuePattern 0-90）
- **曲线绘制**：处理了 **Windows 鼠标加速度**（SendInput 相对位移被非线性放大）——临时关闭加速度 + 位移 ÷1.25 补偿，画完恢复
- **直线**用 SetCursorPos（绝对精确）；**曲线/椭圆**用 SendInput 相对移动 + 补偿
- 实战验证：在画图里画碗/鸭子等图形（完整椭圆 + 贝塞尔轮廓 + 圆柱底座）

## 安装

**一条命令（git 源，产物已入库，无需构建）：**

```sh
dsh plugin --profile web add "github:lak321/dsh-screen-agent#<commit>&path:/"
```

> `<commit>` 换成最新提交号（见仓库主页）。或本地目录：`cd dsh-screen-agent && dsh plugin --profile web add .`

装完**重启 DSH**（`npx -y @deepseek-ai/dsh web`）生效。

> 兼容 DSH Profile：**web**。
> 旧的手动复制 `host/` 并注入 `cordis.patch.yml` 的方式已废弃，由 bundle 层栈安装替代。

```
# 停止当前 DSH，然后重新启动
npx -y @deepseek-ai/dsh web
```

## 使用

- 截图：`POST /api/screen { "op": "capture" }`
- OCR：`POST /api/screen { "op": "ocr", "path": "...", "lang": "zh-CN" }`
- 点击：`POST /api/screen { "op": "click", "x": 100, "y": 200 }`
- 打字：`POST /api/screen { "op": "type", "text": "你好" }`

**对话用法**（DSH agent）：你说「截图看看」「点右上角按钮」「在输入框输入 xxx」「在画图里画个碗」，agent 通过脚本/路由自动执行。

## 工作原理

- **Host 路由**：`webServer.register('/api/screen')`，处理 op 分发
- **PowerShell 脚本**（`lib/scripts/*.ps1`）：
  - `capture.ps1`：虚拟桌面截图（System.Drawing CopyFromScreen）
  - `ocr.ps1`：WinRT `Windows.Media.Ocr`（本地 OCR，中文支持）
  - `mouse.ps1`：user32 `SetCursorPos` + `mouse_event`（DPI aware + 负坐标副屏支持 + Shift 拖拽）
  - `type.ps1` / `key.ps1`：剪贴板 + `keybd_event` / SendKeys
  - `activate.ps1`：`SetForegroundWindow`

## 开发要点（踩坑记录）

1. **DPI 缩放**：`SetProcessDPIAware()` 必须在进程启动时调用，否则鼠标坐标在 125% 缩放下偏移 1.25 倍
2. **鼠标加速度**：SendInput 相对位移被系统鼠标加速度非线性放大（k=2~3.2）→ 曲线变形。临时关闭加速度（`SPI_SETMOUSE 0,0,0`）→ 线性 k=1.25（DPI）→ 位移 ÷1.25 补偿 → 画完恢复（`1,6,10`）
3. **WinRT 集合**：PS 5.1 中 `OcrLine.Words[i]` 索引不可靠，用 `foreach` 遍历
4. **PowerShell 负参数**：`param()` 会把 `-1609` 当参数名解析丢失 → 用 `$args` 手动解析
5. **PS 脚本注释必须英文**：PS 5.1 按 GBK 读无 BOM 文件，中文注释会破坏 here-string

### 新版 Win11 画图（WinUI 3）踩坑（2026-08-17 画碗/写字实测）

Win11 画图已升级为 WinUI 3（Microsoft.UI.Xaml），与旧版行为差异巨大，agent 画图时必须注意：

1. **点色板色块 → 画图卡死**（`Responding=False`，WM_CLOSE 无效）：发生在点任意色块后。
   只能 `taskkill`。恢复流程：截图 → 裁剪画布区域 → 重新打开。
   **不要点色板**；清理用橡皮擦，颜色保持默认黑。
2. **切工具后第一次画布拖拽只激活不绘制**：切铅笔/椭圆等后第一次 down→move→up 被吞。
   解法：每个形状拖 2 次（第一次激活、第二次画），或先画一条"废线"激活（会留痕需擦）。
3. **椭圆工具画不了小椭圆**（如底座 rx135 ry18 拖拽无反应）：改用**铅笔多段拼**
   （20-32 段，每段独立 down→SetCursorPos→up，画 2 遍保闭合）。
4. **文本工具**：
   - `Esc` = **取消文本**（文字直接丢失！）。提交方式：切其他工具（UIA Toggle 铅笔）。
   - **字号用键盘设置**：点字号框 → Ctrl+A → 输入数字 → Enter。
     UIA `ValuePattern.SetValue` 后 Enter 不生效（文字不放大）。
   - **字体列表虚拟化**：UIA 枚举不全。**楷体存在**（列表中文区：yyb/仿宋/宋体/微软雅黑/
     微软雅黑 Light/新宋体/方正粗黑宋简体/**楷体**/汉仪中黑/等线/黑体），需滚动或键盘
     方向键定位（从当前字体按 ↓N 次）。
   - 输入中文：剪贴板 `Set-Clipboard` + Ctrl+V。
5. **手写汉字（铅笔）**：撇方向**右上→左下**（dx 负、dy 正），画成"左上→右下"就变
   捺/点。汉字笔画多，1px 细线手写难识别，本地视觉模型对模糊手写识别差（读成近形字），
   以用户肉眼为准；手写前先了解标准字形再写。
6. **恢复图裁剪**：从整屏截图裁剪画布区域（如 340,265 起 1238x659）时，若截图里恰好
   有弹出的对话框（"另存为"/颜色面板）会一起裁进画布 → 画布"贴着 UI"。用干净的旧截图重裁。
7. **像素扫描防漏**：`GetPixel` 按步长扫描会漏掉奇数行的横线（误判"没画上"），
   细扫（步长 1-2）确认后再重画。
8. **保存/收尾**：`Ctrl+S` 覆盖保存；保存后**必须关闭画图**（`CloseMainWindow`）。
9. **mouse_event 滚轮**：PowerShell 传负 delta 需转 UInt32（`0xFFFFFF88` = 向上 120），
   或改用 UIA `ScrollPattern.Scroll(NoAmount, SmallDecrement)`。

## License

MIT
