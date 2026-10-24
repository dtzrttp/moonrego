# moonrego 设计提案

状态：用户已确认；实施中  
日期：2026-10-23  
项目性质：原创 MoonBit 实现，参考 Rego 公开规范与 Apache-2.0 上游行为

## 1. 项目定位

`moonrego` 是一个可嵌入 MoonBit 程序的 Rego v1 策略解析、检查与执行引擎。它面向原生、Wasm 和 JavaScript 后端，让 MoonBit 应用可以在不启动外部 OPA 进程的情况下，对 JSON `input` 和 `data` 执行确定、受资源限制的策略查询。

核心用户包括：

- 在 MoonBit 服务或 CLI 中加入授权决策的开发者；
- 对配置、基础设施或 CI 输入做策略检查的工具作者；
- 需要在浏览器或受限 Wasm 环境执行策略的应用；
- 希望测试和解释 Rego 决策、但不需要完整 OPA 服务控制面的用户。

项目不会把有限子集描述成完整 OPA 兼容。每个版本都提供机器可读和 README 中的人可读兼容矩阵。

## 2. 官方语义基线

- 语言基线：[OPA Policy Language](https://www.openpolicyagent.org/docs/policy-language)和[Policy Reference](https://www.openpolicyagent.org/docs/policy-reference)。
- 只接受 Rego v1 规则语法；规则体要求 `if`，增量集合规则使用 `contains`。OPA 1.0 之后 v1 语法为默认规则，见[兼容说明](https://www.openpolicyagent.org/docs/v0-compatibility)。
- `undefined` 是“没有求值结果”，不是 JSON `null`，也不自动等于运行时错误。
- 规则体按合取执行，并搜索使全部表达式成立的变量绑定；多个规则定义按 Rego 规则语义合并。
- 编译阶段检查变量安全性、规则冲突、调用参数和递归，错误阶段区分 parse、compile、eval，参考[OPA Errors Guide](https://www.openpolicyagent.org/docs/errors)。
- Rego 测试是以 `test_` 开头的普通规则；undefined 或非 true 为失败，运行时错误单独报告，参考[Policy Testing](https://www.openpolicyagent.org/docs/policy-testing)。

## 3. 首个可运行版本边界

### v0.1 必须支持

#### 模块和规则

- `package`；
- `import data...`，支持 `as` 别名；
- 常量规则；
- `default` 规则；
- Rego v1 完整布尔规则：`allow if { ... }`；
- Rego v1 完整值规则：`decision := value if { ... }`；
- 增量集合规则：`deny contains value if { ... }`；
- 同名规则定义的 OR 语义；
- 查询 `data.package.rule`、`input` 和独立表达式。

#### 值和表达式

- null、boolean、精确 JSON number、string；
- array、object、set；
- 静态和动态引用：点访问、方括号访问；
- `:=` 赋值；
- `==`、`!=`、`<`、`<=`、`>`、`>=`；
- 基础算术；
- `in` 成员关系；
- `some value in collection` 和 `some key, value in collection`；
- `not expression`；
- 表达式块中的分号和换行分隔。

#### 编译检查

- 名称解析和 import 别名；
- 同名规则类型冲突；
- default 与普通规则形状检查；
- 变量安全性及依赖变量的级联诊断；
- 内建函数是否存在、参数数量检查；
- 直接和间接递归检测；
- 源文件、行列和紧凑代码片段诊断。

#### 执行

- JSON `input` 和 `data` 注入；
- 基于环境流的变量绑定和回溯；
- missing reference 和失败表达式产生 undefined 分支；
- 完整规则产生多个不相等值时报告 conflict；
- 可配置 built-in error 模式：OPA 风格 undefined 或严格错误；
- 对对象键和集合结果做稳定排序，保证跨后端输出确定；
- 最大求值步数、递归深度、结果数、集合项数和输出字节预算。

#### 首批纯内建函数

- 聚合：`count`、`sum`、`max`、`min`；
- 字符串：`concat`、`contains`、`startswith`、`endswith`、`lower`、`upper`、`split`；
- 对象：`object.get`、`object.keys`；
- 数组/集合：`array.concat`、集合交并差；
- 类型判断：`is_null`、`is_boolean`、`is_number`、`is_string`、`is_array`、`is_object`、`is_set`。

#### CLI

- `moonrego check POLICY...`：解析和编译检查；
- `moonrego eval QUERY -d DATA.json -i INPUT.json POLICY...`；
- `moonrego test POLICY_OR_DIR...`：发现 `test_` 规则并输出 PASS/FAIL/ERROR；
- `--format pretty|json`；
- `--strict-builtin-errors`；
- 资源预算参数和稳定退出码。

### 后续版本

- partial object rules 和 reference heads；
- rule/function parameters；
- comprehensions；
- `every`、`else`、`with`；
- 用户函数和更完整 built-ins；
- formatter、coverage、trace 和 profiler；
- bundle 读取、capabilities 文件和 schema 检查；
- partial evaluation、Wasm policy compilation和服务控制面适配。

### v0.1 明确不支持

- Rego v0 兼容模式和隐式旧语法；
- HTTP、JWT、时间、随机数等有副作用或环境依赖的 built-ins；
- OPA bundle 签名、REST 服务和插件系统；
- 声称可以替换生产 OPA 的完整能力。

不支持的语法必须在解析或编译阶段给出 `unsupported_feature` 诊断，不能静默采用不同语义。

## 4. 架构

```text
source text
   │
   ▼
lexer ──► tokens + SourceSpan
   │
   ▼
parser ─► syntax AST
   │
   ▼
compiler
   ├─ package/import resolution
   ├─ rule grouping and conflict checks
   ├─ variable safety
   ├─ call checking
   ├─ dependency graph / recursion detection
   └─ lowering to evaluation IR
   │
   ▼
evaluator
   ├─ input/data document resolver
   ├─ binding stream + backtracking
   ├─ rule memoization
   ├─ builtin registry
   ├─ resource budget
   └─ deterministic result normalization
   │
   ▼
query results / undefined / structured diagnostics
```

### 求值模型

每个规则体表达式都接受一组变量环境，并产生零个或多个新环境：

- 零个环境表示该分支 undefined/不成立；
- 一个环境表示确定绑定；
- 多个环境表示集合或动态引用产生多个候选绑定。

这种模型直接表达 Rego 的合取、迭代和回溯。`undefined` 不进入公开 `Value` 枚举，而由“无结果”表示，从类型层面避免与 `null` 混淆。

完整规则收集所有成功分支。如果得到多个不同值则产生 conflict；如果没有结果则使用 default，仍没有则 undefined。增量集合规则收集、去重并稳定排序全部成功值。

### 数字模型

Rego/JSON 数字不能直接降级为 IEEE `Double`。v0.1 使用任意精度十进制表示，优先验证 `moonbitlang/x/decimal`；如果它无法满足跨后端和 JSON 规范要求，则用 core `BigInt` 实现十进制系数加尺度的内部类型。最终选择必须经过 `moon ide doc` 和多后端测试后固定，并记录兼容限制。

## 5. 包结构

```text
moonrego/
  moon.mod
  moon.pkg                    # facade
  syntax/
  parser/
  value/
  compile/
  eval/
  builtin/
  diagnostic/
  internal/
    lexer/
    ir/
    budget/
  cmd/moonrego/
  examples/authz/
  examples/config_check/
  conformance/
  testdata/
  docs/
    compatibility.md
    architecture.md
    sources.md
  README.mbt.md
  README.md
  LICENSE
  NOTICE.md
```

公开 AST、Value、Compiler、PreparedQuery、Result 和 Diagnostic 类型由对应公共包拥有；根包仅选择性 re-export，避免从 `internal/*` 暴露具体类型。

## 6. API 形状

精确 MoonBit 签名在模块创建后通过 `moon ide doc` 与编译器确认。设计固定以下能力：

- `parse_module(source, filename)`；
- `Compiler` 添加多个模块和基础 data，返回不可变的 `Program`；
- `Program.prepare(query)` 完成查询解析和编译；
- `PreparedQuery.evaluate(input, options)` 返回结果集合和可选统计；
- JSON 与 Rego `Value` 双向转换；
- Diagnostic 包含阶段、稳定错误码、消息、文件、SourceSpan 和相关位置；
- Builtin 注册表区分纯函数与被禁用的环境函数；
- EvaluationOptions 提供严格错误和资源预算。

核心库不读文件、不打印日志、不读取环境变量。CLI 才负责文件系统、JSON 输入和终端输出。

## 7. 错误处理

错误按阶段分离：

- Parse：非法 token、字符串转义、括号、规则头和 v0 语法；
- Compile：unsafe variable、递归、冲突规则、未知 built-in、参数数量、unsupported feature；
- Eval：预算耗尽、严格 built-in 错误、完整规则冲突、数值错误；
- CLI：文件 I/O、JSON 解析、参数和退出码。

默认 built-in 类型或算术错误使当前分支 undefined；严格模式把它提升为 EvalError，行为与官方 `--strict-builtin-errors` 的概念一致。

## 8. 依赖与许可

- 项目许可证：Apache-2.0。
- Rego 行为与术语参考 OPA 官方文档；若引入 OPA 测试用例，保留 Apache-2.0 来源和文件级说明。
- JSON 优先使用当前 MoonBit 核心库。
- 任意精度数字候选：`moonbitlang/x@0.5.6` 的 decimal 或当前 core BigInt；项目创建后核实 API。
- CLI 文件系统候选：`moonbitlang/x@0.5.6` 的 fs；限制在 CLI 包。
- 核心解析、编译、回溯执行和 built-ins 独立实现，不嵌入或调用 OPA 二进制。
- `aloyscc/moon_cel@0.1.0` 是邻近策略项目，但 CEL 与 Rego 的语言、类型和求值模型不同；README 将直接说明适用场景差异。

## 9. 测试与兼容验证

### 词法与语法

- 每种 token、注释、普通/原始字符串、数字和错误位置；
- 合法 Rego v1 规则；
- v0 隐式规则体、缺失 `contains` 等拒绝案例；
- 错误恢复后一次报告多个独立问题。

### 编译

- import 和 package 名称解析；
- unsafe variable 及依赖级联；
- complete/incremental/default 规则冲突；
- 直接、间接递归；
- built-in 参数数量和 unsupported feature。

### 求值

- missing reference 与 null 的差异；
- 多绑定、回溯、`some ... in`、动态引用；
- complete rule 的 OR、default 和 conflict；
- incremental set 去重；
- negation 只接受安全变量；
- built-in 默认 undefined 与严格错误；
- 资源预算在精确边界中止；
- native、wasm-gc、wasm、js 输出顺序一致。

### 差分验证

- 为支持矩阵内的每个语言功能建立独立的小型 corpus；
- 使用明确记录版本的官方 `opa eval` 生成期望结果；
- corpus 记录 policy、query、input、data、结果或错误类别；
- CI 不依赖联网或临时下载 OPA；已审核的 fixture 随仓库保存并注明来源；
- 对不支持功能使用负向测试，证明会明确拒绝。

### CLI 和文档

- 授权示例：角色、路径和资源所有者；
- 配置检查示例：输出增量 `deny contains message`；
- `check`、`eval`、`test` 端到端；
- README 的 MoonBit API 示例作为文档测试。

实现遵循测试驱动：每项语义先加入失败测试并记录输出，再写最小实现，通过后重构。

## 10. 验收条件

- 两个真实示例可从 CLI 和 MoonBit API 运行；
- 支持矩阵内 fixture 与记录的 OPA 结果一致；
- unsupported 功能全部明确诊断；
- parse/compile/eval 错误阶段和源码位置准确；
- 资源预算测试证明不会无界求值；
- `moon fmt --check`、`moon check --deny-warn`、`moon test --deny-warn`、构建和示例通过；
- `moon info` 生成接口经过审阅；
- README、兼容矩阵、架构、来源、LICENSE、NOTICE、CI 和 Mooncakes 元数据齐全；
- 手写源码、fixture、生成文件分别统计。

## 11. 自然提交计划

每次只在真实功能通过对应验证后提交：

1. 模块骨架、许可证、NOTICE、兼容矩阵骨架；
2. SourceSpan、token 和词法失败测试/实现；
3. 值、引用和表达式 AST；
4. Pratt 表达式解析器；
5. package/import/rule 解析；
6. Diagnostic 与解析错误恢复；
7. Rego Value、精确数字和 JSON 桥；
8. 规则索引、名称解析和冲突检查；
9. 变量安全分析；
10. 依赖图和递归检测；
11. IR 与基本绑定环境；
12. 引用解析、赋值和比较；
13. 迭代、`some in` 和回溯；
14. complete/default 规则执行；
15. incremental set 和冲突处理；
16. 首批 built-ins 与严格错误模式；
17. 资源预算和确定性排序；
18. `check`/`eval` CLI；
19. `test` CLI 和测试规则发现；
20. 示例、差分 corpus、README 和 API 文档；
21. CI、多后端验证、接口文件和申报自查。

提交数量取决于真实完成步骤；不做空提交、日期回填或机械拆分。

