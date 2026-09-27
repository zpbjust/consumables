# HomeParts 完整手工测试 Case

这份文档按“第一次接触 App 的测试者”来写。请按顺序测试，后面的 Case 会使用前面创建的数据。

当前版本的 RevenueCat 尚未正式配置，因此所有功能都应开放：可以创建超过 5 个物品和超过 1 个住宅，测试期间不应弹出内购墙。

## 一、测试前准备

- 一台 iPhone 真机：用于相机、相册和通知权限测试。
- 建议再准备一台小屏 iPhone 或把字体调大，用于检查滚动和文字适配。
- 把 `TestAssets/LabelOCR` 文件夹中的 5 张 PNG 保存到手机相册。
- 测试前删除旧 App 后重新安装，确保从欢迎页和空数据开始。
- 文档中的“今天前 100 天”等日期不要求精确到同一天，日期选择器中选择大约对应的日期即可。

## 二、先建立这 4 个标准物品

### 物品 A：过期的楼上空气滤芯

- Name：`Upstairs Air Filter`
- Category：`Air & HVAC filters`
- Brand：`Filtrete`
- Model number：`MPR-1000`
- Size：`16 x 25 x 1`
- Room：`Living room`
- Exact location：`Upstairs ceiling return vent`
- Replacement schedule：开启
- Last replaced：今天前 100 天
- Replace every：`3 months`（90 天）
- Notify：开启
- Stock at home：`1`
- Preferred store：`Home Depot`
- Typical price：`18.99`
- Product link：`https://www.homedepot.com/`
- Notes：`Use the red frame filter`

预期：它应显示为 Overdue（已过期）。Home 提醒、Items 列表、Schedule 卡片和 Item Detail 顶部及 Replacement schedule 都应明确显示 `OVERDUE` 徽标和到期日期，不能只依靠日期颜色区分。

### 物品 B：即将到期的厨房净水滤芯

- Name：`Kitchen Water Filter`
- Category：`Water filters`
- Brand：`AquaPure`
- Model number：`AP-4396508`
- Size：`10.2 x 2.4 in`
- Room：`Kitchen`
- Exact location：`Inside refrigerator, upper right`
- Replacement schedule：开启
- Last replaced：今天前 25 天
- Replace every：`30 days`
- Notify：关闭
- Stock at home：`0`
- Preferred store：`Target`
- Typical price：`29.99`
- Product link：`target.com`

预期：它应显示为大约 5 天后到期。

### 物品 C：较晚到期的烟雾报警器电池

- Name：`Smoke Alarm Batteries`
- Category：`Batteries`
- Brand：`Energizer`
- Model number：留空
- Size：`9V`
- Room：`Bedroom`
- Exact location：`Ceiling alarm near the door`
- Replacement schedule：开启
- Last replaced：今天
- Replace every：`6 months`
- Stock at home：`2`
- Preferred store：`Costco`

预期：只填写 Size、不填写 Model number 也可以保存，并出现在 Schedule 的 Later 区域。

### 物品 D：不设计划的灯泡

- Name：`Kitchen Pendant Bulb`
- Category：`Light bulbs`
- Brand：`LumaHome`
- Model number：`LH-A19-9W`
- Size：`A19 / 9W / 800 lm`
- Room：`Kitchen`
- Exact location：`Pendant above island`
- Replacement schedule：关闭
- Stock at home：`3`

预期：物品可以保存，但不会出现在 Schedule。

---

## Case 01：首次启动和空首页

操作：

1. 删除 App 后重新安装并打开。
2. 阅读欢迎页，点击 `Get started`。
3. 检查底部导航和空首页。

预期：

- 没有测试数据、乱码、异常大空白或被裁掉的文字。
- 底部依次显示 Home、Items、Schedule、Shopping、Settings 五个 Tab。
- 首页显示空状态和 `Scan or add your first item`。
- 空数据时不显示虚假的统计、历史或 Demo 内容。

## Case 02：新增物品的必填校验

操作：

1. 点击 `Scan or add your first item`。
2. 不填内容，查看底部 `Save item`。
3. 只填 Name，仍不填 Model 和 Size。
4. 再填 Model 或 Size，并选择 Room。
5. 点击 `Cancel`，确认可正常退出。

预期：

- Name、Room，以及 Model/Size 两者中的至少一个是必填项。
- 条件不满足时 `Save item` 为不可点击状态；满足后恢复正常。
- Cancel 不会保存半成品。
- 页面是完整全屏流程，底部保存按钮不会被键盘或 Home Indicator 遮挡。

## Case 03：创建 4 个标准物品

操作：

1. 按“二、先建立这 4 个标准物品”逐个新增 A、B、C、D。
2. 每个物品保存后，从 Items 再次进入详情核对。

预期：

- 4 个物品都能保存。
- A 显示 Overdue，B 显示近期到期，C 显示较晚到期，D 不显示到期日。
- 单住宅时 Add/Edit 页面不显示可选择的 Home 行，只在 `Where it lives` 右侧轻量显示 `My home`。
- Room 和 Exact location 的用途清楚，购买信息不会与安装位置混在一起。

## Case 04：新增和编辑页的滚动、键盘收起

对 Add item 和 Edit item 各执行一遍：

1. 点击 Name，输入文字后点击卡片内没有按钮的空白处。
2. 再点击 Brand，向上拖动页面。
3. 点击 Typical price 打开数字键盘，再点击空白处。
4. 点击 Product link，再向下拖动到 Notes。
5. 点击 Notes 输入多行文字，点击空白处。
6. 键盘显示时点击 Picker、Toggle、Stepper 和日期控件。
7. 点击键盘上方 `Done`。

预期：

- 点击真正的空白区域会收起键盘。
- 上下拖动页面时键盘跟随手势交互式收起。
- `Done` 始终可收起键盘，包括数字键盘。
- 点击输入框本身不会立即把键盘关闭。
- 点击 Picker、Toggle、Stepper、日期、Save 或 Cancel 不会被“收键盘手势”吃掉，需要的操作仍然生效。
- 页面可以从顶部滚到最底部，最后一个 Notes 和 `Save item` 都能完整看到。

## Case 05：英文、中文和倾斜标签识别

对 `TestAssets/LabelOCR` 中 5 张图片分别执行：

1. Add item > `Choose photo`，选择测试图片。
2. 等待 `Reading label…` 完成。
3. 在 `Review label` 检查并编辑识别结果。
4. 点击 `Show all recognized text`，再点击隐藏。
5. 第一次点击 `Cancel`；第二次重新扫描后点击 `Apply details`。

预期建议值：

- `01-hvac-filter-en.png`：Filtrete / MPR-1000 / 16 x 25 x 1 in / Air & HVAC filters。
- `02-water-filter-en-angle.png`：AquaPure / AP-4396508 / 10.2 x 2.4 in / Water filters。
- `03-led-bulb-en-warm.png`：LumaHome / LH-A19-9W / A19 / 9W / 800 lm / Light bulbs；如果 `lm` 被识别为 `Im`，应可手工修正。
- `04-water-filter-zh.png`：净水器滤芯 / 清泉 / QY-RO-05 / 10英寸 / Water filters，不应出现乱码。
- `05-vacuum-filter-unlabeled.png`：CleanNest / CN-HF220 / 9.5 x 8.2 x 1.1 in / Appliance parts。

共同预期：

- 识别后先让用户确认，不直接覆盖已有字段。
- Cancel 不应用识别结果；Apply details 才应用。
- Review label 中编辑字段时，点击空白和拖动都能收起键盘。
- 原 Name 已填写时，识别建议不会擅自覆盖原 Name。

## Case 06：Enter manually 和识别失败

操作：

1. 扫描任一测试图，在 Review label 点击 `Enter manually`。
2. 再选择一张没有文字或非常模糊的照片。
3. 在失败提示中点击 `Enter manually`。

预期：

- 两种情况下都返回 Add item，并把输入焦点放到 Model number。
- 按钮确实有反应，不会停留在原页面。
- 失败时给出“清晰、光线充足、标签占满画面”的提示，不显示乱码或无意义文本。

## Case 07：真机拍照、照片压缩和持久化

操作：

1. 真机点击 `Scan a label`，允许相机权限并拍摄。
2. 保存物品，彻底结束 App，再重新打开。
3. 进入详情和编辑页查看照片。

预期：

- 相机取消和拍摄都能正常返回。
- 照片比例正常，不被拉伸；重新打开 App 后仍存在。
- 大照片保存速度合理，App 不因原图过大而卡死。
- 识别与保存都可以离线完成。

## Case 08：首页结构与提醒概览

操作：

1. 建好 A、B、C、D 后回到 Home。
2. 检查顶部 Attention 和家庭卡片。
3. 点击提醒卡内的 A 或 B，确认进入对应物品详情。
4. 点击 `My home` 家庭卡片，分别切换 `Rooms` 和 `All items`。
5. 在 Rooms 中进入 Living room，核对只显示该房间的物品。
6. 新建 `Lake House` 后返回首页，确认两个住宅显示为两张独立家庭卡片。
7. 检查页面中是否还存在跳转 Schedule、Shopping 或重复新增的快捷入口。

预期：

- A、B 出现在需要关注的区域；C、D 不错误显示为近期到期。
- Home 顶部不再重复显示 Add 按钮，也不显示搜索框；新增入口只保留下方浮动 `Add item`。
- Home 只承担状态概览，不重复提供 Schedule、Shopping、Items 的导航入口。
- 提醒项可以直接打开对应物品详情；没有到期物品时只显示 `Everything is on schedule`，不显示多余按钮。
- 首页不再把多个住宅和房间名称拼在同一张小卡片里；每个住宅独立显示房间数、物品数和需处理数量。
- 点击家庭卡片后才进入 Rooms / All items；Rooms 显示该住宅的完整房间名、物品数和到期状态。
- 点击房间后只显示该住宅、该房间下的物品；空房间显示空状态，不混入其他住宅的数据。
- 浮动 Add item 不遮挡最后一项内容。

## Case 09：标题折叠、顶部间距和 Items 搜索

操作：

1. 依次进入 Home、Items、Schedule、Shopping、Settings，检查页面刚打开时的标题和顶部间距。
2. 在每个有足够内容的页面向上滑动，让大标题离开顶部。
3. 确认标题折叠为导航栏中间的小标题，再滑回顶部。
4. 进入 Items 并向上滑动，确认大标题和说明滑出后，居中小标题、Search、Category 和 Room filter 吸附在顶部。
5. 在标题刚好折叠的位置反复轻微上下拖动 5 次。
6. 留下 1 至 2 个 Item，在短列表中上滑后松手让页面回弹，再慢慢下拉到顶部。
7. 滑动过程中观察状态栏时间、电量区域的背景。
8. 搜索 `MPR-1000`、`16 x 25`、`Living room`、`Home Depot`，并组合 Category 和 Room 筛选。
9. 搜索一段不存在的文字。
10. 键盘显示时快速上滑、慢慢下拖，再点击空白。

预期：

- 五个主页面刚进入时，页面标题紧贴内容区域，不出现系统 Large Title 预留的大块空白。
- 向上滑后标题在顶部中间以小标题显示；回到顶部后恢复大标题。
- Home 不提供重复搜索入口；需要查找物品时统一使用 Items。
- Items 吸顶区域保持不透明，列表内容不会从小标题、搜索框或筛选项后面透出。
- 状态栏区域始终保持纯背景色，滚走的标题、说明和 Item 卡片不能出现在时间或电量图标下面。
- 短列表回弹时，大标题重新出现之前小标题已经隐藏，任何时刻都不能同时看到两个 `Items` 标题。
- 在标题折叠临界位置慢拖或回弹时，吸顶区域不会闪烁、跳高或反复显隐。
- 上滑和下滑时 Search、Category、Room 的位置保持稳定，结果数量与居中小标题只做平滑交叉切换，不引起列表跳动。
- Items 中型号、尺寸、房间、位置、分类和商店均能用于搜索。
- 筛选可以组合使用，结果数量正确。
- 无结果时显示明确空状态。
- 列表不会穿透搜索框、不会横向滚动或左右留出异常白边。
- 点击空白和拖动都可以收起键盘。

## Case 10：物品详情信息完整性

操作：

1. 进入物品 A 详情。
2. 核对 What to buy、Location、Replacement schedule、Notes。
3. 点击 `Open product link`。
4. 点击 Edit，修改 Brand 和 Stock 后保存。

预期：

- 型号、尺寸、库存、常买商店、典型价格、住宅、房间、精确位置、到期日都能看到。
- 分别从 Home、Items、Schedule 和 Shopping 打开物品详情：详情都应像独立任务一样全屏打开，底部五个 Tab 不显示，顶部 `Close` 可回到原页面。
- Product link 没写 `https://` 时也能正常打开浏览器。
- 长名称和长位置最多换行显示，不互相覆盖。
- 编辑保存后详情立即更新。

## Case 11：Schedule 到期日与状态筛选

操作：

1. 打开 Schedule。
2. 检查标题下方只有紧凑的 `DUE DATE` 卡片，默认显示 `Any due date`，不应直接占用一整块月历高度。
3. 点击 `Choose`，确认进入全屏 `Choose due date` 页面；页面说明这里选择的是物品的“计划更换到期日”，不是通知发送时间。
4. 点击 `Previous`、`Next` 切换前后月份，再点击 `Today` 返回当前月份。
5. 找到带小圆点的日期并点击，确认页面自动关闭，`DUE DATE` 卡片显示所选日期和任务数量，下方只显示该日到期的物品。
6. 再次点击 `Change`，尝试点击一个没有圆点的日期，然后点 `Close`。
7. 点击紧凑卡片中的 `Clear` 回到完整计划。
8. 依次点击 `All`、`Overdue`、`Coming up`、`Later`，核对按钮数量和结果。
9. 在 `All` 中查看 Overdue、Coming up、Later 三个分区，点击 A、B、C 卡片进入详情，并检查 D 是否出现。
10. 另外新增 6 个启用 1 year 计划的物品，再回到 Schedule 滑到 Later 底部。

预期：

- Schedule 主页面的日期筛选卡高度紧凑，不再常驻显示 6 周月历；完整月历只出现在独立全屏选择页。
- 全屏日期页的 `Choose due date` 顶栏完整位于状态栏下方，说明文字和月历不能被顶栏或灵动岛遮挡。
- 全屏月历固定显示 6 周，切换月份时不会忽高忽低；月份、星期和日期都不截断。
- `Previous`、`Next` 可连续切换月份；离开当前月后显示 `Today`，点击后准确返回当前月。
- 有到期任务的日期显示状态点；过期日期用橙色点，其他计划日期用绿色点；当天有独立描边。
- 只有带状态点、实际存在计划任务的日期可选；无任务日期置灰且不可点击，不能把主列表筛成空白。
- 选择有效日期后立即刷新列表，并隐藏 `All`、`Overdue`、`Coming up`、`Later` 状态标签，不让日期和状态两套筛选同时显示；`Clear` 后恢复状态标签和完整分区列表。
- 点击任意筛选会清除日期选择并显示对应结果；`All` 保持分区列表，其他筛选只显示对应物品，不重复套一层分区标题。
- A 在 Overdue，B 在 Coming up，C 在 Later。
- D 因未启用计划而不出现。
- 同一个物品不会同时出现在两个分区。
- Later 超过 5 个时全部都能看到，不会静默隐藏第 6 个及之后的物品。
- 长列表可完整滚动，切换月份、日期和筛选时不闪烁、不跳动。

## Case 12：从 Schedule 记录更换

操作：

1. 在 A 的 Schedule 卡片点击 `Mark as replaced`。
2. 查看 Inventory，Quantity 设为 1。
3. 确认 Store 自动带出 `Home Depot`，Price 填 `18.99`，Note 填 `Changed upstairs filter`。
4. 点击空白收键盘并保存。

预期：

- 页面清楚说明保存会扣减 1 个库存并更新下次日期。
- A 的 Stock 从 1 变 0。
- A 不再 Overdue，下次到期日按新日期 + 90 天计算。
- 详情的 Replacement history 出现记录。

## Case 13：库存不足时记录更换

操作：

1. 对 Stock 为 0 的 B 点击 Mark as replaced。
2. Quantity 设为 2 并保存。

预期：

- 页面提示库存不足时仍会记录更换，但库存保持 0。
- 保存后库存不会出现负数。
- History 的 Quantity 正确为 2。

## Case 14：购物清单合并和商店预填

操作：

1. 在 A 详情连续两次点击 `Add to shopping list`。
2. 打开 Shopping，核对数量。
3. 点击浮动 `Add to list`，选择 B。
4. 查看 Preferred store 是否自动带出 Target，把 Quantity 改为 3 后 Add。

预期：

- 这里的 A 指同一个已保存物品；Shopping 中只生成一条 A 的购物记录，卡片显示 `To buy: 2`，不生成两条重复记录。
- A 和 B 是两张彼此独立的商品卡片；数据上只合并同一物品，不把不同商品挤进同一张大卡。
- B 自动带出 Target，也允许手动修改。
- 每张卡片同时显示 `To buy` 和 `Stock at home`，购买数量与家中库存含义不混淆。
- Add to shopping 页面点击空白、拖动和键盘 Done 都能收起键盘。

## Case 15：购买后增加库存且不能重复增加

操作：

1. 记下 A 当前库存。
2. 在 Shopping 点击 A 的 `Bought · add to stock`。
3. 观察 Purchased 区域和 A 的库存。
4. 快速连续尝试点击购买按钮两次，或从 Store mode 重复操作。

预期：

- 一次购买把 A 的库存增加 2。
- 条目进入 Purchased，并显示 Added to stock。
- 同一个购物条目只能入库一次，重复操作不能再次增加库存。

## Case 16：Store mode

操作：

1. 保证至少有两个未购买条目，点击 `Start shopping`。
2. 核对品牌、型号、尺寸、购买数量、库存、价格和商店。
3. 点击 `Copy model`，粘贴到任意输入框验证。
4. 点击 `Next item`，再点击 Product link。
5. 逐个 `Mark bought`。

预期：

- 信息来自真实物品数据，不是 Demo 内容。
- 点击 Copy model 后立即显示 `Model copied` 提示；关闭提示后可把完整型号粘贴到其他输入框。
- Next item 不越界、不跳到已购买条目。
- 全部完成后显示 `All picked up`，Done 可退出。

## Case 17：Replacement history 和真实更换周期

操作：

1. 给同一物品再记录两次不同历史日期，例如 100 天前、10 天前和今天。
2. 打开物品详情和 Schedule 底部。

预期：

- History 按最新日期在上排列。
- 记录展示日期、数量、商店和备注。
- 有至少两段有效间隔后，App 显示该物品的 observed average / real cadence。
- Price 为总价、Quantity 大于 1 时，Typical price 更新为单个平均价格。

## Case 18：单住宅与多住宅的位置逻辑

操作：

1. 只有 My home 时打开 Add item，确认没有 Home Picker。
2. Settings > Homes & rooms > `Add home`，创建 `Lake House`。
3. 再次 Add item。

预期：

- 一个住宅时不让用户做无意义选择。
- 两个住宅后出现 Home Picker，可在 My home 和 Lake House 间切换。
- 切换 Home 后 Room 列表同步更新，不保留另一个住宅的房间。

## Case 19：新增、改名和删除房间

操作：

1. 进入 Lake House，新增 `Basement`。
2. 左滑 Basement，重命名为 `Workshop`。
3. 新建一个位于 Workshop 的物品。
4. 再把 Workshop 改名为 `Garage Workshop`。
5. 尝试删除 Garage Workshop 和 Lake House。

预期：

- 新增/改名页面是可正常退出的完整输入页。
- 输入时点击空白、拖动、Return 和键盘 Done 均可收键盘。
- 房间改名后关联物品自动改为新房间名。
- 有物品的房间/住宅不能删除，并说明原因。
- 最后一个房间和最后一个住宅不能删除。

## Case 20：Settings 信息结构

操作：

1. 打开 Settings。
2. 依次进入 Homes & rooms、Notifications、Backup, restore & export、How HomeParts works、Privacy、About。
3. 返回 Settings。

预期：

- Settings 首屏只保留有实际用途的入口，不出现大量技术说明或删除本地数据等干扰项。
- 每个入口都以独立全屏页面打开，底部五个 Tab 不显示；顶部 `Close` 可回到 Settings，顶部间距自然。
- RevenueCat 未配置时 Pro 卡片显示测试期间功能开放，点击不会打开空白内购墙。

## Case 21：通知权限和提醒提前量

操作：

1. Settings > Notifications，把时间依次设为 due date、3 days、1 week、2 weeks。
2. 检查 Permission 状态；首次使用时点击 `Allow notifications` 并允许。
3. 回到物品 A 编辑页，确认 Notify 开启并保存。
4. 在系统设置中关闭通知，再回到 Notifications 页面。

预期：

- 提前量会保存，重开 App 后不丢失。
- 首次允许后显示成功提示，Permission 更新为 `Allowed`，按钮不会像没有反应。
- 拒绝权限不会影响 Schedule 内到期日。
- 被拒绝时 Permission 显示 `Not allowed`，并出现 `Open iOS Settings`；从系统设置返回后状态自动刷新。

## Case 22：完整备份、导入和 CSV

操作：

1. 确保现有数据包含：2 个住宅、物品照片、购物条目、更换历史。
2. Settings > Backup, restore & export > `Prepare full backup`，再 Share 保存 JSON。
3. 点击 `Prepare CSV export`，保存 CSV 并打开查看。
4. 修改住宅名并删除一个物品。
5. Import backup 选择 JSON，第一次 Cancel，第二次 `Import and replace`。

预期：

- JSON 和 CSV 都能生成和分享。
- CSV 包含 Item、Category、Home、Room、Date、Quantity、Price、Store、Note，逗号和双引号内容不会破坏列。
- Cancel 不改变当前数据。
- 确认导入后住宅、房间、物品、照片、库存、购物、设置和历史全部恢复。
- 错误文件不会覆盖当前数据。

## Case 23：删除物品

操作：

1. 给待删除物品添加照片、购物条目和更换记录。
2. 详情底部点击 `Delete item`，第一次取消。
3. 再次删除并确认。

预期：

- 取消后数据不变。
- 确认后物品、照片、对应购物条目和通知一起删除。
- Home、Items、Schedule 数量立即更新，无残留空卡片。

## Case 24：重启、离线和旧数据兼容

操作：

1. 完全结束 App 后重开。
2. 开启飞行模式，浏览、搜索、编辑、记录更换并新增购物项。
3. 从升级前已经有数据的版本覆盖安装当前版本（如有旧测试包）。

预期：

- 数据和照片重启后仍存在。
- 核心功能离线可用，无需登录。
- 旧物品即使没有库存、商店、价格和 Product link 字段，也能正常打开；新字段默认为空或 0。

## Case 25：小屏、大字体和 iPad 滚动适配

操作：

1. 在小屏 iPhone 检查 Home、Items、Schedule、Shopping、Settings。
2. 系统字体调到较大，再重复检查。
3. iPad 横屏和竖屏各检查一次。
4. 每个长页面从顶部快速滑到底，再慢慢滑回顶部。

预期：

- 没有内容被 Tab Bar、浮动按钮、键盘或 Home Indicator 永久遮挡。
- 卡片、图片和文字不横向溢出；长文字能换行或合理缩小。
- iPad 内容保持可读宽度并居中，不把手机卡片无限拉宽。
- 滚动流畅，页面无异常穿透、闪烁或突然跳位。

## Case 26：全 App 键盘回归清单

以下每个输入位置都要做“输入文字 > 点击空白 > 再输入 > 拖动页面 > 再输入 > 点击 Done”：

- Items 搜索。
- Add item / Edit item 的 Name、Brand、Model、Size、Exact location、Store、Price、Product link、Notes。
- Review label 的 Name、Brand、Model、Size。
- Record replacement 的 Store、Price、Note。
- Add to shopping 的 Preferred store。
- Homes 的 Home name。
- New home、Add room、Rename room。

统一预期：

- 空白点击和页面拖动均能收起键盘。
- 输入框、按钮、Toggle、Stepper、Picker、链接和列表项仍可正常点击。
- 收键盘后页面不跳回顶部，不丢失已输入文字。
- 没有任何页面必须强制退出才能收起键盘。

## 三、本轮通过标准

- 26 个 Case 主流程全部通过，无崩溃、乱码和数据丢失。
- 首页、计划、详情、购物和设置使用真实数据，没有 Demo 占位内容。
- 购买会增加库存；更换会扣减库存；库存永远不会小于 0；相同购买不会重复入库。
- 所有长页面都能完整滚动；所有输入页都支持空白点击、拖动和 Done 收键盘。
- RevenueCat 未配置时，所有功能开放且不出现不可用内购墙。
- 真机相机、相册、OCR 和通知权限流程正常。
