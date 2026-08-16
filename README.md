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

### 1. 放置插件包

把 `host/` 目录复制到你的 DSH 插件目录：

```
~/.dsh/profiles/node_modules/dsh-screen-agent/  ← host/ 内容
```

> `~` = `C:\Users\<用户名>`（Windows）。

### 2. 启用插件

编辑 DSH web profile 配置 `~/.dsh/profiles/web/cordis.patch.yml`，追加：

```yaml
- insert:
    - id: screen-agent
      name: 'dsh-screen-agent'
```

配置示例见 [`install/cordis.patch.example.yml`](install/cordis.patch.example.yml)。

### 3. 重启 DSH

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

## License

MIT
