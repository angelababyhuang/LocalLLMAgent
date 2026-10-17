# 本地多模态智能体平台 · Wayfinder 地图

> **状态：bootstrap（本地 Markdown 中转）。** 目标 tracker 是 GitHub issues，但本机 shell 当前不可用（`3221225794`，DLL 初始化失败），且仓库尚未建立，`gh` / `git` 都跑不起来。故先把地图与票据落在 `.scratch/`，等 shell 恢复、仓库就绪后迁移为 GitHub issues（正文可直接 `gh issue create` 复用）。

## Destination

锁定一版可直接施工的规格包——架构、数据模型与词表、持久化设计、接口契约、工作台交互草案——并先过「段落↔素材匹配质量」闸门 Spike（200 段落 × 300 图人工标注，nDCG@10 ≥ ~0.55；否则改走 caption 中介 + LLM 相关性判定）。实施本身拆到后续会话。

## Notes

- 领域：本地优先的多模态素材库（10 万图 / 1 万视频 / 几千篇中文 MD）+ 叙事文本交叉匹配工作台。
- 主机分工：Windows 保存全部资料与库；MacBook Pro 64GB 仅作 LM Studio 推理端点（局域网 HTTP）。
- 约束：运行时零出网（安装/开发可联网）；中文为主；单人使用；敏感资料。
- 技术裁定（来自调研）：无端到端成熟工具；Kuzu 已归档；ComfyUI GPL-3.0 不作内核；jina-v3 非商用；云视频理解排除；Pixeltable 仅作 ETL 候选。
- 已定根决策（首次梳理）：终点 = 规格包 + 闸门 Spike；工作台页面为主、Coding Agent 管建设与记忆；零运行时出网；复用组件 + 自研领域层；过程记忆三层（会话纪要 / ADR / 票据状态，Markdown 为准 + SQLite 索引）；匹配结果页内预览 + 人工接受/拒绝反馈。
- 每个会话开工前：读本 map + `docs/agents/` + 最近 ADR；相关决策用 grilling + domain-modeling。

## Decisions so far

<!-- 已关闭票据的索引，一行一条：标题 — 一句结论 — 链接 -->

（暂无）

## Not yet specified

- 摄取管道：Pixeltable vs 自建 Python；增量/去重/缩略图/关键帧（等数据模型定了才 sharp）。
- 大库性能：sqlite-vec 10 万级 + 混合过滤的 P95（等 schema 定了再测）。
- 评测集版本化：人工反馈如何沉淀成回归集。
- 备份/迁移、软删除后的恢复。
- Coding Agent 与工作台服务的接口形态（CLI / HTTP / MCP）。
- LM Studio 的并发、超时与结构化输出（JSON schema / grammar）支持度。

## Out of scope

- 任何云端的推理 / 存储 / 视频理解。
- 多用户协作与权限体系。
- 移动端。
- 对外分发（涉及 GPL 等许可取舍的产品化假设先不做）。
