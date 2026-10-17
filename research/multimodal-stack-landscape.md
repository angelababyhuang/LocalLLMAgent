# 本地多模态知识平台：工具版图与技术选型调研

> 调研时间：2026-10（本次会话）。网络工具可用；本机 shell 不可用（进程退出码 3221225794），
> 因此所有事实核验通过抓取官方文档 / GitHub API / LicenseDB 完成。
> 标记约定：**✅** = 本次已抓取来源核实；**⚠️** = 未能抓取到一手来源，属经验判断，需自行复核。

---

## 0. 结论先行

**没有任何成熟工具覆盖端到端。** 这个项目的核心动作是「叙事文本 → 场景/角色/动作抽取 → 对**素材**（图片、视频片段）打分排序」，
而市面上的工具分成两族，两族都不做这件事：

- DAM 族（Immich / PhotoPrism / LibrePhotos / ResourceSpace / Daminion / Eagle）：索引已存在的资产，
  检索范式是 **资产→资产相似** 或 **单句 query→资产**，没有「段落语义结构 → 多粒度资产」这一层，也没有视频分段。
- RAG / Agent 族（Khoj / RAGFlow / AnythingLLM / Open WebUI / Dify / Langflow / Flowise）：
  检索范式是 **文档 chunk→文档 chunk**，资产只是附件，不做素材级标签体系（scene/character/action），更不做镜头切分。

唯一「半个」命中者是 **Pixeltable**：它真的把视频帧、转写、嵌入、相似度检索做成了同一张表上的声明式计算列，
但它只是数据层/ETL 库，没有标签维度模型、没有排序评测、没有节点工作台。

所以答案是：**自建一个薄的「匹配与编排层」，把成熟的组件装进去**（见 §4）。风险不在工具缺失，而在跨模态匹配质量（见 §6）。

---

## 1. 表 A：DAM / 知识库 / RAG 工具逐个核验

| 工具 | 实际做什么 | 做「叙事文本→素材匹配」？ | License | 可完全离线 | 成熟度 | 判决 |
|---|---|---|---|---|---|---|
| **Immich** | 自托管照片/视频备份与浏览，ML 服务做 CLIP 智能搜索、人脸、OCR | 否。仅整段 query→单资产（CLIP 向量），无视频镜头切分、无 scene/character/action 维度 | AGPL-3.0 ✅ | 是（可关遥测、自建 ML 容器） | 很高（~116k★，TypeScript 活跃）✅ | **只借数据模型**，不要当底座 |
| **PhotoPrism** | Go 写的 AI 相册：图像分类、人脸、OCR、相似图 | 否。同上，且视频只取缩略图 | AGPL-3.0 **+ 附加条款**（PhotoPrism 商标/品牌条款，GitHub 标 NOASSERTION）✅ | 是 | 高（~40k★）✅ | 商标条款对产品化不友好，弃 |
| **LibrePhotos** | 自托管相册，语义搜索、人脸、相册时间线 | 否 | MIT ✅ | 是 | 中，迭代慢 ⚠️ | 不如 Immich，弃 |
| **ResourceSpace** | PHP 企业级 DAM（博物馆/慈善/公共部门），元数据 schema、工作流、权限 | 否。强在**元数据字段与审批流**，AI 打标是插件且偏云端 | GitHub 无法自动识别；官方称开源、商业支持收费 ✅（具体 SPDX 未核实 ⚠️） | 部分（PHP+MySQL，可离线） | 高（企业老牌） | 借 **元数据/字段集设计** |
| **Daminion** | 商业 DAM（Windows 客户端 + Server），AI 打标引擎 | 否。资产级标签，无叙事结构 | 商业闭源 ✅ | 部分（AI 打标有云端依赖 ⚠️） | 高（商业） | 仅作交互参考 |
| **Eagle** | 商业桌面素材管理器（设计素材），标签/文件夹/配色搜索 | 否 | 商业闭源 ✅ | 是（纯本地） | 高（设计师圈） | 交互参考（标签+画板） |
| **Pixeltable** | Python 声明式多模态库：`pxt.Video/Image/Audio` 列 + 计算列（抽音轨、whisper 转写、VLM 描述）+ `EmbeddingIndex` + `similarity()` 排序 + FastAPI 服务化 | **半个**：能做「文本→视频摘要向量」检索，但需要你自己定义标签维度和匹配/排序逻辑 | Apache-2.0 ✅ | 是（可挂本地模型函数） | 中高，迭代快 | **采纳为素材 ETL + 索引层**（最关键的复用点） |
| **SiYuan** | 块级笔记/知识库，本地优先，有 AI 接口 | 否（笔记检索） | AGPL-3.0 ✅ | 是 | 高 | 可作开发过程记录的可选前端，非核心 |
| **Trilium(Next)** | 层级笔记，脚本化强 | 否 | AGPL-3.0 ✅ | 是 | 高 | 同上，非核心 |
| **Khoj** | 个人 AI 第二大脑：索引文档/网页/笔记，语义检索 + 聊天 | 否（doc→doc），图片支持弱 | AGPL-3.0 ✅ | 是 | 中高 | 不采纳 |
| **RAGFlow** | 文档深度解析（DeepDoc/OCR）、chunk、GraphRAG、可视化引用 | 否。**无视频**；图片仅作为文档内嵌元素解析 | Apache-2.0 ✅ | 是 | 高（活跃） | 借 **GraphRAG 的实体/关系抽取思路** |
| **AnythingLLM** | 工作区式文档问答、向量库适配、Agent | 否 | MIT ✅ | 是 | 高 | 不采纳 |
| **Open WebUI** | 自托管 LLM 前端（多模型、RAG、工具） | 否 | BSD-3 系 + 品牌附加条款 ✅(GitHub 未识别) | 是 | 很高 | 可作**运维/调试台**，不作业务层 |
| **Dify** | LLM 应用平台：工作流、知识库、Agent、发布 API | 否（doc RAG + 编排） | Apache-2.0 + 附加条件（多租户 SaaS/品牌限制）✅(未识别) | 是（自托管） | 很高 | 可借工作流 UX，不作底座 |
| **Langflow** | 可视化搭建 LLM 流程（Python 生态） | 否 | MIT ✅ | 是 | 高 | 节点工作台参考 |
| **Flowise** | 可视化 LLM 流程（JS 生态） | 否 | Apache-2.0 ⚠️（GitHub 未识别） | 是 | 高 | 同上 |

---

## 2. 表 B：视频侧（本地流水线 vs 云产品）

| 组件 | 作用 | License | 结论 |
|---|---|---|---|
| **PySceneDetect** | 内容感知/自适应/哈希三类镜头切分，输出 shot 列表与时间码 | BSD-3-Clause ⚠️（GitHub 未识别） | **采纳**：镜头是视频的最小可靠单元 |
| **ffmpeg** | 抽帧、转码、音频分离 | LGPL/GPL（构建相关）⚠️ | 采纳（注意 GPL 构建的合规） |
| **faster-whisper** | CTranslate2 版 Whisper，词级时间戳，比原版快数倍 | MIT ✅(仓库) | **采纳**，large-v3-turbo 起步 |
| **whisper.cpp** | ggml 版 Whisper，CPU/Apple 友好 | MIT ⚠️ | 备选（Mac 上 Metal 友好） |
| **PaddleOCR / RapidOCR** | 画面文字（字幕、招牌）OCR | Apache-2.0 ⚠️ | 采纳，用于画面文字通道 |
| **Aana SDK**（Mobius Labs → Dropbox） | 自托管多模态视频/音频**流水线部署框架**（转写、VLM、向量化、API） | Apache-2.0 ✅ | **最接近的 OSS 参照物**，可借鉴其 pipeline 抽象，不必直接采用 |
| **Twelve Labs** | 云视频理解 API（embed / generate，语义检索、章节化） | 商业云 ✅ | 云 only，**零 egress 目标下不可用** |
| **VideoDB** | 云视频"数据库" + Director Agent 框架 | 商业云 ✅ | 同上，排除 |
| **OSS "video RAG"** | 存在若干 GitHub 实验仓库（个人项目级），均为「切帧→CLIP→向量检索」的 demo | 各异 ⚠️ | **无成熟项目**：没有一个做到「镜头切分 + ASR 对齐 + 分段 VLM 描述 + 段落级排序 + 中文」 |

**结论**：视频分段索引必须自建，但每个零件都是现成的。真正的难点是**镜头 ≠ 叙事场景**的合并策略。

---

## 3. 表 C/D：本地模型（64 GB 统一内存的 MacBook Pro）

### C. 嵌入（中文强）

| 模型 | 规模 | 维度/上下文 | License | 备注 |
|---|---|---|---|---|
| **BGE-M3** | 568M | 1024 / 8192 | MIT ✅ | 稠密+稀疏+ColBERT 三合一，中文稳，**首选基线** |
| **Qwen3-Embedding** | 0.6B / 4B / 8B | 最高 32k ⚠️ | Apache-2.0 ⚠️ | 多语 MTEB 榜首梯队；0.6B 用于批量，4B 用于精排 |
| **jina-embeddings-v3** | 570M | 1024 / 8192 | **CC BY-NC-4.0（非商用）** ⚠️ | 商用项目**不要用** |
| **CLIP ViT-L/14** | ~428M | 768 | MIT ⚠️ | 图文共享空间，**中文弱**，只作对照 |
| **Chinese-CLIP** | ViT-B/L | 512–768 | MIT ✅ | 中文图文检索专用，**图片侧首选** |

64 GB 上这些都能同时常驻，占用都在 GB 级，不是瓶颈。

### D. VLM（图像/视频帧描述与打标）

| 模型 | 可选规模 | License | 64 GB 可行性 | 用途 |
|---|---|---|---|---|
| **Qwen3-VL** | 2B/4B/8B/32B（另有 MoE 大杯）✅(仓库) | Apache-2.0 ✅ | 8B 舒适；32B（4bit）可跑 | **主力**：中文描述、结构化 JSON 打标、OCR |
| **Qwen2.5-VL** | 3B/7B/72B | Apache-2.0 ⚠️ | 7B 舒适 | 稳定备选，生态成熟（GGUF/MLX 齐全） |
| **InternVL3 / 3.5** | 1B–78B | MIT ✅(仓库) | 8B/14B 舒适 | 备选，OCR 与图表强 |
| **Florence-2** | 0.23B / 0.77B | MIT ⚠️ | 极轻 | **批量预打标**：快、便宜，质量一般 |
| **Moondream** | 2(2B) / 3 Preview(9B MoE, 2B 激活, 32k ctx) | 代码 Apache-2.0 ✅；**权重为自有 Model License 1.0**（非 OSI，多数商用免费）✅ | 很容易 | 实时/批量 caption + grounding（框、点、分割） |

**推荐**：主力 **Qwen3-VL-8B**（结构化打标 + 中文）；批量粗筛 **Florence-2 或 Moondream 2**；
高价值素材再用 32B 复跑。ASR 用 **faster-whisper large-v3-turbo**。

---

## 4. 表 E/F：关系存储与节点工作台

### E. 关系/图存储（Windows、可嵌入性优先）

| 方案 | 嵌入/部署 | License | 判决 |
|---|---|---|---|
| **SQLite + FTS5** | 单文件，Python 内置 | Public Domain ✅ | **主存储**：素材表、标签表、边表、全文检索 |
| **sqlite-vec** | SQLite 扩展，向量近邻 | Apache-2.0 ✅ | 采纳，但注意其自述仍是 **pre-v1**，API 会变 ⚠️ |
| **Kuzu** | 嵌入式属性图（Cypher + 向量 + FTS），本是理想选择 | MIT ✅ | **不要新建依赖**：仓库已 `archived`，最后推送 2025-10 ✅；2026-02 有报道称 Apple 收购 ✅⚠️ |
| **Neo4j Community** | JVM 服务，需独立进程 | GPLv3 ⚠️ | 可行但重；仅在需要 Cypher 生态时考虑 |
| **SurrealDB** | 单二进制，图+向量+文档 | Business Source License 1.1 ✅ | 非 OSI，商业使用需看条款；技术诱人、许可有雷 |
| **Graphiti** | Python 时序知识图谱（Agent 记忆），双时间轴（valid_at / created_at） | Apache-2.0 ✅ | **借它的位时序边模型**；其主后端是 Neo4j/FalkorDB，Kuzu 路线已随 Kuzu 归档而失效 ⚠️ |

**结论**：本项目的图只有 2–3 跳（段落→场景→角色→素材），**SQLite 一张 typed-edge 表 + 递归 CTE 完全够**，
不要引入第二个数据库（双写一致性是最常见的自伤）。

### F. 节点工作台

| 方案 | License | 说明 | 判决 |
|---|---|---|---|
| **React Flow (xyflow)** | MIT ✅ | 只是画布/连线库，执行引擎、节点类型系统、持久化都要自己写 | **首选**：可控、可嵌进任意 UI |
| **Rete.js** | MIT ✅ | 自带数据流/控制流引擎，TS 优先 | 次选（引擎更" batteries included"，生态小） |
| **ComfyUI** | **GPL-3.0** ✅ | 图执行 + 队列 + 自定义节点，但为图像生成而生 | 内部自用可，**产品化有 copyleft 传染风险**，不建议当内核 |
| **n8n** | Sustainable Use License（非 OSI）⚠️ | 集成/自动化强，交互式节点图 + 自定义节点 | 许可不适合分发；仅当纯内部 |
| **Langflow (MIT ✅) / Flowise (Apache-2.0 ⚠️)** | 见左 | 现成 LLM 图执行与调试 UX，可读源码抄作业 | 参考实现，不作底座 |

---

## 5. 表 G：影视工业的数据模型（借模型，不借软件）

| 工具 | 形态/许可 | 值得借的模型 |
|---|---|---|
| **Autodesk Flow Production Tracking（原 ShotGrid）** | 商业 SaaS ⚠️ | `Project → Sequence → Shot → Asset(Character/Prop/Set) → Task → Version → PublishedFile → Note`。**Version 是关键抽象：素材的"一次交付"与镜头解耦** |
| **ftrack** | 商业 ⚠️ | 同上，且 `Note/Review` 与 Version 强绑定（审片意见可追溯到具体版本） |
| **Kitsu**（CGWire） | **AGPL-3.0 ✅**，可自托管 | `Production → Episode → Sequence → Shot`，`Asset/Casting`（角色↔镜头选角关系），`Task` 状态流，`Preview` |
| **StudioBinder / Boords** | SaaS ⚠️ | 分镜 ↔ 镜头列表 ↔ 场次的**双向映射**，以及"场次 = 叙事单元"的字段集 |
| **OpenTimelineIO** | Apache-2.0 ✅ | `Timeline → Stack → Track → Clip(source_range, metadata)`，**视频分段的时间轴标准**，Python 可跑在 Windows |

**可落地的融合模型**（建议直接采用）：
`Project → Chapter → Passage`（叙事侧） ↔ `Scene → Character/Action`（抽取侧） ↔ `Asset(Image|Video) → VideoSegment(shot, t_in, t_out)`（素材侧），
中间用带类型的边 `implies / depicts / features / performed_in / derived_from` 连接，边表带 `valid_from/valid_to`（借 Graphiti 的位时序）。
开发过程库不是另建系统，而是同一张图里的 `Decision / ADR / Spike` 节点，用 `decided_in`、`supersedes` 连到被决策的对象上——这才是"两个库有关系"的正确做法。

---

## 6. 表 1 归纳：谁都缺什么（Gap Analysis）

1. **段落级语义结构**没人做：没有工具把一段中文叙事抽成 `scene / character / action` 三元组。
2. **跨模态"不对称匹配"**没人做：现有检索是 query↔资产；我们要的是"抽取出的结构"↔"带维度标签的资产"，且要**可解释的分数拆解**（角色对上了几成、动作对上了几成）。
3. **视频片段级**是最大空白：DAM 只到视频文件；OSS video RAG 只到"帧→CLIP→片段"demo；云产品（Twelve Labs/VideoDB）能力对口但**必须联网**，与零 egress 冲突。
4. **镜头 ≠ 场景**：PySceneDetect 给镜头，叙事给场次，中间的对齐/合并逻辑没有现成实现。
5. **两个库的关系**：DAM 有资产元数据，笔记工具有文档图，但"开发决策 ↔ 素材"的关联没有产品级实现。
6. **可审计的排序**：没有工具能回答"为什么这张图排第一"，而这在创作流程里是刚需。
7. **中文 + 敏感内容**：主流工具默认英文标签体系与云端模型；中文人名别名、称谓、隐晦动作描述的归一化要自己做。

---

## 7. 推荐参考架构（具体组件 + 许可）

```
┌ Windows PC（本地，无外网） ────────────────────────────────┐
│ 工作台 UI：React + React Flow (MIT)  ← 自建 DAG 执行器      │
│   └ FastAPI (MIT) 业务 API                                  │
│ 存储：SQLite (Public Domain) + FTS5 + sqlite-vec (Apache-2.0)│
│   ├ asset / tag / edge / work_decision 表（单一数据文件）    │
│   └ 向量表：text_emb / image_emb / segment_emb               │
│ ETL：Pixeltable (Apache-2.0) 或自建 Python 管道              │
│   ├ 图片：EXIF → 缩略图 → VLM 打标 → Chinese-CLIP 向量       │
│   └ 视频：PySceneDetect(BSD-3) → ffmpeg 关键帧               │
│            → faster-whisper(MIT) 对齐 → VLM 分段描述         │
│ 打包：Docker Desktop / 本地 venv；模型权重预下载，遥测全关   │
└──────────────────────────┬──────────────────────────────────┘
                           │ 局域网 HTTP（唯一网络路径）
┌ MacBook Pro 64GB ────────┴──────────────────────────────────┐
│ LM Studio（OpenAI 兼容 /v1）：                               │
│   chat/vision：Qwen3-VL-8B (Apache-2.0) [+32B 复跑]          │
│   text：Qwen3-8B/14B (Apache-2.0)                            │
│   embed：Qwen3-Embedding-0.6B/4B (Apache-2.0) 或 BGE-M3(MIT) │
│   rerank：bge-reranker-v2-m3 (MIT)                           │
└─────────────────────────────────────────────────────────────┘
```

**匹配流程（核心，需自研 ~1500 行）**
1. `Passage → LLM(JSON schema) → {scenes[], characters[], actions[]}`（每项带置信度与原文 span）
2. 每条抽取项生成多路 query：字面向量（Qwen3-Embedding）+ 标签结构（scene/character/action 的枚举命中）
3. 候选召回：向量近邻（sqlite-vec）+ FTS5 布尔（角色名/动作词）+ 标签精确匹配，三路取并集
4. 融合排序：`score = w1·cos + w2·tag_overlap + w3·rerank(bge-reranker) + w4·duration_prior`，权重可调、分数拆解落库
5. 人工在工作台里接受/否决 → 写回 `accepted/rejected` 边 → 形成评测集（**这一步是项目长期价值的来源**）

**明确不采纳**：Immich/PhotoPrism 作底座（模型与检索范式不合）、ComfyUI 作内核（GPL-3.0）、
Kuzu（已归档）、Neo4j（重）、jina-v3（非商用）、n8n（非 OSI）、任何云 API。

---

## 8. 最危险的未知（必须先做 Spike）

| # | 未知 | 为什么危险 | Spike 验收标准 |
|---|---|---|---|
| 1 | **段落↔图片 的实际匹配质量** | 文本嵌入与图文 CLIP 空间不互通，"中文叙事段落"与"图像 caption"的分布差距可能让排序接近随机 | 200 段落 × 300 图的**人工标注小集**，测 nDCG@10；低于 ~0.55 就要改架构（改用 caption 中介 + LLM 相关性判定） |
| 2 | **Mac 端 VLM 吞吐** | 决定"每镜头抽 1 帧还是 5 帧"，直接决定整个视频库的成本 | 在 LM Studio 上测 8B/32B：单帧延迟、连续 500 帧的稳定显存与降速曲线；确认**多帧图片输入**是否被支持 |
| 3 | **镜头→场景 合并** | PySceneDetect 的切点与叙事场次不对齐，片段库会碎 | 30 段视频人工标注场次边界，测合并启发式（对白间隙 + 画面相似度 + 字幕主题漂移）的边界 F1 |
| 4 | **sqlite-vec 的能力天花板** | pre-v1，且混合检索（向量+FTS+过滤）的性能未验证 | 10 万向量 + 3 路过滤的 P95 延迟；确认 Windows 轮子可用；准备 LanceDB/DuckDB-VSS 作 B 计划 |
| 5 | **LLM 结构化抽取的稳定性（中文）** | 角色别名（"他/阿澈/沈公子"）、隐含动作会导致图结构噪声 | 100 段样本上 JSON 合法率 ≥99%、角色归并准确率 ≥85%；LM Studio 的 structured output/grammar 支持度 |
| 6 | **"零 egress"的可证明性** | 工具会偷偷联网（更新检查、遥测、模型下载、字体/CDN） | 断网 + 抓包（Wireshark/防火墙出站全禁）跑完整流程 0 外连；逐一关闭各组件遥测并写进部署清单 |
| 7 | **敏感内容治理** | 素材敏感，需可删除、可审计、可加密 | 设计：SQLite 加密（SQLCipher）+ 素材目录 EFS/BitLocker + 软删除与访问日志；确认无云端备份路径 |

---

## 9. 主要来源

许可与元数据（GitHub API / LicenseDB，本次已抓取）：
[immich](https://api.github.com/repos/immich-app/immich) ·
[photoprism](https://api.github.com/repos/photoprism/photoprism) ·
[PhotoPrism 例外条款](https://scancode-licensedb.aboutcode.org/photoprism-exception-3.0.html) ·
[librephotos](https://github.com/LibrePhotos/librephotos) ·
[resourcespace](https://github.com/resourcespace/resourcespace) ·
[pixeltable](https://github.com/pixeltable/pixeltable) ·
[siyuan](https://github.com/siyuan-note/siyuan) ·
[Trilium](https://github.com/TriliumNext/Trilium) ·
[khoj](https://github.com/khoj-ai/khoj) ·
[ragflow](https://github.com/infiniflow/ragflow) ·
[anything-llm](https://github.com/Mintplex-Labs/anything-llm) ·
[open-webui](https://github.com/open-webui/open-webui) ·
[dify](https://github.com/langgenius/dify) ·
[langflow](https://github.com/langflow-ai/langflow) ·
[Flowise](https://github.com/FlowiseAI/Flowise) ·
[kuzu（archived）](https://api.github.com/repos/kuzudb/kuzu) ·
[surrealdb LICENSE](https://surrealdb.dev/license) ·
[graphiti](https://github.com/getzep/graphiti) ·
[sqlite-vec](https://github.com/asg017/sqlite-vec) ·
[xyflow](https://github.com/xyflow/xyflow) ·
[rete](https://github.com/retejs/rete) ·
[ComfyUI](https://github.com/comfyanonymous/ComfyUI) ·
[n8n](https://github.com/n8n-io/n8n) ·
[kitsu](https://github.com/cgwire/kitsu) ·
[OpenTimelineIO](https://github.com/AcademySoftwareFoundation/OpenTimelineIO) ·
[aana_sdk](https://github.com/dropbox/aana_sdk) ·
[Chinese-CLIP](https://github.com/OFA-Sys/Chinese-CLIP) ·
[Qwen3-VL](https://github.com/QwenLM/Qwen3-VL) ·
[InternVL](https://github.com/OpenGVLab/InternVL) ·
[FlagEmbedding/BGE](https://github.com/FlagOpen/FlagEmbedding) ·
[moondream 模型页](https://moondream.ai/models) ·
[moondream 权重许可](https://moondream.ai/licenses/model/1.0)

功能与背景：
[Pixeltable 官网（视频表/嵌入索引/服务化）](https://www.pixeltable.com/) ·
[PySceneDetect](https://github.com/Breakthrough/PySceneDetect) ·
[faster-whisper](https://github.com/SYSTRAN/faster-whisper) ·
[whisper.cpp](https://github.com/ggml-org/whisper.cpp) ·
[Twelve Labs 企业版](https://www.twelvelabs.io/enterprise) ·
[VideoDB Director](https://docs.videodb.io/pages/build-with-agents/director) ·
[Daminion AI 打标](https://daminion.net/features/ai-tagging/) ·
[ResourceSpace 开源说明](https://www.resourcespace.com/blog/open-source-what-does-that-mean) ·
[Kuzu 被收购报道（2026-02）](https://finance.sina.cn/2026-02-12/detail-inhmpqkp4046488.d.html) ·
[BGE-M3 模型卡](https://huggingface.co/BAAI/bge-m3) ·
[Qwen3-Embedding 模型卡](https://huggingface.co/Qwen/Qwen3-Embedding-8B) ·
[jina-embeddings-v3 模型卡](https://huggingface.co/jinaai/jina-embeddings-v3) ·
[LM Studio OpenAI 兼容端点](https://lmstudio.ai/docs/app/api/endpoints/openai)
