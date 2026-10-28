# Rego `every` 语义支持设计

> 历史设计说明：文中单变量对象迭代绑定键的假设已于 2026-10-28
> 更正为绑定值。当前行为见 docs/compatibility.md 和 OPA 语言文档。

状态：设计已获用户批准（2026-10-24）；实施计划见 `docs/superpowers/plans/2026-10-24-rego-every.md`

日期：2026-10-24

项目：`moonrego`

范围：为现有 Rego v1 子集增加 `every` 普遍量化表达式

## 1. 目标与用户场景

策略作者经常需要表达“集合中的每个元素都满足某个条件”。当前 `moonrego` 支持 `some ... in` 和数组、集合、对象推导式，但没有直接的普遍量化语法。使用者只能通过辅助规则或推导式绕行，策略不够直观。

本变更增加 Rego v1 的 `every`，使使用者可以直接写出通用校验，例如：

```rego
package access

allow if {
  every role in input.roles {
    role != "blocked"
  }
}
```

实现目标是与 OPA 文档定义的核心语义一致，并继续明确 `moonrego` 只实现已列出的 Rego 子集，不声称完整 OPA 兼容。

## 2. 官方语义基线

- [OPA Policy Language：Universal Quantification 与 Every Keyword](https://www.openpolicyagent.org/docs/policy-language)：`every` 为 domain 中每个元素绑定变量并检查 body；任一绑定没有成功 body 求值时整体 undefined；空 domain 为 true；`every` 不向外层求值引入新绑定；可选 key 仅在 body 中可见；不能否定 `every`。
- [OPA Rego Keyword: every](https://www.openpolicyagent.org/docs/policy-reference/keywords/every)：包含数组、对象和集合的官方示例，以及对象键和值的使用方式。
- [OPA Policy Reference](https://www.openpolicyagent.org/docs/policy-reference)：作为语法和语言术语的补充参考。

以上页面为滚动更新的官方文档。本设计固定文档链接和可见语义；实施时必须记录用于差分测试的具体 OPA 版本和命令，不能把滚动页面当作固定版本测试结果。

## 3. 语法和支持边界

`every` body 必须非空。OPA 的公开语法把 `query` 定义为一个必需的
`literal` 加零个或多个后续表达式，因此空 body 是 parse error。

### 3.1 支持的形式

```rego
every value in collection {
  expression
  another_expression
}

every key, value in collection {
  expression
}
```

首批支持：

| Domain | 单变量形式 | 双变量形式 |
| --- | --- | --- |
| Array | 每项绑定为 `value` | 数组索引绑定为 `key`，元素绑定为 `value` |
| Object | 每个属性名绑定为 `value`，与现有 `some value in object` 一致 | 属性名绑定为 `key`，属性内容绑定为 `value` |
| Set | 每个成员绑定为 `value` | 不在本次支持范围；按明确的 `unsupported_feature` 诊断处理 |

单变量对象行为遵循当前 `some value in object` 的行为：遍历属性名。数组双变量索引为 MoonRego 的 Rego number 值；对象 key 为 string。Set 使用单变量形式，不提供顺序保证。

Domain 表达式在进入迭代前、以外层环境求值一次。仅支持求值为 array、object 或 set 的值。未定义 domain 使 `every` 未定义；运行时非集合值返回带源码位置的 eval 阶段 `rego_type_error`，而不是当作空集合处理。

Body 使用当前规则体的表达式语法和分隔规则，可以包含已有支持的赋值、比较、引用、`some`、推导式、内建函数及嵌套 `every`。本次不增加 `else`、`with`、用户函数或新的 built-in。

### 3.2 明确拒绝的形式

- `not every ...` 以及括号包裹后再否定的等价形式：解析或编译阶段产生稳定的 parse/compile 诊断，不降级解释。
- `every key, value in set { ... }`：产生 `rego_unsupported_feature` 诊断。
- 非集合 domain：运行时给出 `rego_type_error`。
- 空 domain 的 body 不执行，结果为成功。

如果 OPA 的固定版本差分结果与上述非集合或不支持形式的错误类别不同，保留有文档的 MoonReGo 子集诊断，并在兼容矩阵中标出差异；不得宣称错误类别完全兼容。

## 4. 求值与作用域语义

每个现有表达式从一个 `Environment` 产生零个或多个 `(Environment, Value)` 结果。`every` 作为一个表达式执行以下步骤：

1. 以当前外层环境求值 domain。undefined 时返回零个结果。
2. 将集合展开为 `(key?, value)` 项：数组按 index，object 按 key/value，set 按 value。
3. 对每个项创建仅供 body 使用的局部环境，绑定 `every` 头中的变量。
4. 在该局部环境上调用现有 `eval_body`。只要 body 至少产生一个成功结果，该项满足；body 的变量绑定结果全部丢弃。
5. 任一项没有成功结果时，整个表达式返回零个结果。
6. 所有项均满足时返回一个 `(原外层环境, true)` 结果；因此 body 和头部的局部绑定不泄漏到外层。

空数组、空对象或空集合没有迭代项，第 6 步直接成立，符合空真语义。普通 body 表达式在每次迭代内仍遵循现有 Rego 的存在性求值：一个 domain 项只要有至少一条 body 求值路径成功，就算该项通过。

### 变量安全和重名

两个 binder 使用相同名字时，按 Rego 的重复变量一致性处理：每个
key/value pair 只有在两值相等时才进入 body。此边界有本地相等/不等测试
及待运行的 OPA v1.21.4 oracle fixture；oracle 运行前仍标为待确认。

- 编译安全检查先在外层变量环境检查 domain。
- `every` 的头部变量只添加到 body 的局部安全环境；body 检查结束后丢弃局部环境，不得改变后续外层表达式的安全性。
- 在 body 内，头部变量必须绑定到当前 domain 项；body 其余引用仍可读取已经安全的外层变量。
- 官方文档说明局部作用域和不泄漏，但没有明确列出头部变量与已绑定外层同名时的完整规则。实施前加入 OPA oracle 案例锁定该情况；不得直接复用当前 `Environment::bind` 的同名变量统一行为而不核对 OPA。实现须遵循 oracle 并加入回归测试。

### 预算与错误

- `every` 本身、每个 domain 项和 body 内执行的表达式共用 `EvalContext` 中同一剩余步数预算。
- 迭代项计费使用当前 `SomeIn` 的 `context.charge(span)` 机制；嵌套 `every` 不创建独立预算。
- 预算耗尽沿用既有结构化诊断并立即停止，不得被“某个 body 成功”吞掉。
- body 内的普通 undefined/条件失败只使当前项失败；已有 eval 诊断（例如严格 built-in error 或资源耗尽）继续按当前全局错误策略传播。
- diagnostics 使用 `every` 源码跨度或更精确子表达式跨度，并保留 Parse、Compile、Eval 阶段区分。

## 5. 解析器、AST 和编译器影响

### 语法树

在 `syntax.Expr` 增加显式 `Every` 变体，建议形状为：

```text
Every(key_name?, value_name, domain, body, span)
```

这是控制流和作用域构造，优先保留显式 AST，而不是在解析时改写成推导式或 `some` 加否定。显式节点能保留源码跨度，表达空真、局部环境、错误传播和预算行为，并便于之后输出精确诊断。实现 AST 变更时更新 `span()`、syntax/debug 表示及所有穷尽匹配。

### 词法和解析

- 将 `every` 识别为关键字 token。
- 在表达式前缀解析路径中解析一变量或双变量头、`in`、domain 和大括号 body。
- 复用规则体现有表达式分隔与错误恢复规则；正确处理嵌套大括号、对象、集合、推导式及嵌套 `every`。
- 对缺少变量、逗号后缺少变量、缺少 `in`、缺少 body 大括号和未闭合 body 给出包含行列和跨度的 parse 诊断。
- 解析/编译时拒绝 `not every`，包括 `not (every ...)`。

### 编译安全检查

安全检查为 `every` 建立局部副本：先检查 domain，再将头部 binder 加入局部已绑定列表，按顺序检查 body。仅把 `domain` 的外层依赖留给外围表达式；不可把 binder 或 body 的赋值带回外层。对头部重复变量名采用固定 OPA oracle 结论，测试编译结果及运行行为。

## 6. 首个可演示功能

一个不依赖网络的授权策略演示：检查输入中的所有资源标签都不是禁用标签；另有一个对象校验示例，用双变量形式同时检查对象 key 和 value。演示应覆盖全部符合条件、任意一项失败、空集合和缺少输入字段四种结果，展示 `every` 的核心语义和 CLI 诊断。

示例只使用 MoonReGo 已支持的语法和内建函数。除非当前 CLI 能执行模块文件，不在 README 中展示未经运行验证的命令。

## 7. 测试与验收

### Parser / syntax

- 一变量和双变量头的 AST 与源码跨度；
- 空 body 拒绝；
- 数组、对象、集合 domain 的语法；
- 多表达式、分号/换行、嵌套大括号、嵌套 `every`；
- 缺变量、缺 `in`、缺大括号及未闭合 body 的错误位置；
- `not every` 与 `not (every ...)` 拒绝。

### Compiler

- domain 引用为安全与不安全变量；
- body 使用外层已绑定变量；
- body 变量在 `every` 之后不可用；
- binder 只在 body 内安全；
- 头部变量名与已绑定外层同名的 OPA oracle case；
- 双变量 set 拒绝，错误阶段和码稳定。

### Evaluator

- 数组、对象和 set 的单变量形式；
- 数组索引及对象 key/value 的双变量形式；
- 重复双 binder 名的一致性行为；
- 全部通过、某项失败、空集合、domain 未定义、非集合 domain；
- body 多条成功路径的存在性语义；
- binder/body 结果不泄漏，嵌套 `every` 正确；
- 每一项均进入共享预算，边界内通过、刚好耗尽时停止；
- OPA oracle 固定版本对全部受支持表格项产生匹配结果；不支持项产生有记录的预期诊断。

### 跨目标与项目门禁

- native、wasm、wasm-gc、JS 目标结果一致；
- `moon fmt --check`、`moon check --deny-warn --target all`、`moon test --deny-warn --target all`、`moon build --deny-warn --target all`；
- `moon info` 后审阅生成接口文件，只保留有意的公共 AST/API 变化；
- 运行 CLI 演示并核对 README 命令和输出。

验收完成还要求更新 `docs/compatibility.md`、`README.md`、`README.mbt.md` 和来源/兼容说明，注明 `every` 语言子集和任何与 OPA 的差异。

## 8. 备选方案和取舍

### 改写成集合推导式

可以将 `every` 改写为对逐项 predicate 结果集合的比较。这会复制或扭曲 body 表达式语义，并增加临时集合和额外预算；错误位置、早停和局部作用域也更难保持。因此选择独立 AST 节点和直接迭代。

### 用 `some`、helper rule 和 negation 表达

这是 Rego 中表达“无反例”的一种现有技巧，但需要改写业务逻辑或额外定义规则，不能满足直接解析官方 `every` 语法的目标；而且 `not every` 本身在 OPA 中不允许。该方式可作为用户自行编写策略的替代表达，不是 MoonReGo 的实现。

### 只实现集合输入

单集合支持无法覆盖官方文档中常见的数组遍历及对象 key/value 校验，不能支撑所选场景；因此首批覆盖数组、对象、set 的单变量形式及数组/对象双变量形式。

## 9. 风险与缓解

| 风险 | 影响 | 缓解 |
| --- | --- | --- |
| 现有 safety analysis 按顺序修改同一 bound 列表 | binder 或 body 变量泄漏到外层 | 使用局部副本；增加编译后续引用失败测试 |
| Environment 同名绑定当前表示统一，不支持遮蔽 | every binder 与外层同名时语义偏差 | 先用固定版本 OPA 建 oracle；如需遮蔽，采用局部环境覆盖层或等效局部绑定表示 |
| body 多结果和失败分支语义被误写成全路径都成功 | 与 Rego 存在性求值不一致 | 每个 domain 项以 `eval_body` 是否至少返回一个结果判断 |
| set 的迭代顺序跨后端不同 | 输出或预算边界不稳定 | every 只返回成功/失败，不暴露迭代结果；固定测试不依赖顺序，并复用稳定值顺序策略 |
| 含 built-in 诊断时提前成功会掩盖错误 | 结果与严格错误策略不一致 | 复用 EvalContext diagnostics 和当前中止规则；为严格 built-in 错误加 every 回归测试 |
| 把 `not every` 当成普通 unary not | 接受 OPA 明确禁止的语法 | Parser/Compiler 双层防护和正反测试 |
| 仅有示例测试，漏掉空集或作用域 | 错误语义进入公共 API | 分层测试和固定版本 OPA 差分 corpus |

## 10. 来源和非目标

本实现使用独立 MoonBit 代码；OPA 文档用于语言行为、示例和兼容差分，不复制 OPA 实现代码。本设计本身不引入依赖、上游代码或外部测试数据。后续若导入 OPA corpus，须在文件级记录上游路径、版本/提交和 Apache-2.0 许可信息，并更新仓库的来源说明。

本次不包括 `else`、`with`、函数规则、完整 OPA 编译器、bundle、策略服务、`every` 查询优化或生产 OPA 替代声明。

## 11. 实施前必须固定的决定

1. 以一个具体 OPA 稳定版运行 binder 与外层同名、非集合 domain、未定义 domain 等 oracle case，并保存版本号、命令和输出。
2. 若当前 Parser 的表达式体解析器无法安全复用，先为“带 `{...}` 的表达式体”提取小型共享解析函数，再添加 `Every`；避免对现有推导式或规则语法做无关重构。
3. 公共 AST 是否直接暴露 `Every` 变体，以及受影响的包 `.mbti` 文件，只由 `moon info` 生成后审阅，不手改生成文件。

## 自查记录

- 设计覆盖了用户场景、语法、作用域、安全检查、求值、错误、预算、测试、演示、取舍、风险和来源。
- 对象单变量迭代明确沿用现有 `some value in object` 的行为，未把 key/value 语义混淆。
- 空 domain、局部变量不泄漏、任一项失败、`not every` 限制均依据 OPA 官方文档写入。
- 外层同名遮蔽及非集合错误类别文档没有给出完整规则，因此列为固定 OPA oracle 的实施门槛；没有伪称已验证。
- 本设计已获用户批准；实现、测试和当前剩余限制记录在同目录实施计划、`docs/verification.md` 与 `conformance/opa/README.md`。
