# Turn-Based Idle RPG — 밸런스 가이드

> 밸런스 작업 시 어떤 숫자를 수정해야 하는지 빠르게 확인하기 위한 프로젝트용 문서입니다.

---

## 1. 재화 구분

프로젝트에서는 두 가지 재화를 사용합니다.

| 표기 | 재화 | 용도 |
|---|---|---|
| `G` | Gold (골드) | 일반적인 캐릭터/스킬 강화 및 HP/MP 회복 |
| `C` | Crystal (크리스탈) | 캐릭터/스킬 해금 및 일부 공용 업그레이드 |

### 크리스탈을 사용하는 항목

- 캐릭터 해금
- 스킬 습득
- 던전 몬스터 강화율 감소
- 던전 보상 배율 증가
- 배틀 속도

### 골드를 사용하는 항목

- 전투 후 HP 회복
- 전투 후 MP 회복
- 캐릭터 HP / MP / ATK / DEF / SPD 업그레이드
- 스킬 강화

---

# 2. 기본 원칙

- **캐릭터 기본 스탯(HP / MP / ATK / DEF / SPD)** → 각 캐릭터의 `.tres` Resource Inspector에서 수정
- **업그레이드 증가량 / 업그레이드 비용 / 비용 증가율 / 스킬 강화량** → `GameManager.gd`
- **행동 간 추가 딜레이** → `BattleManager.gd`
- **게임 배속** → `GameManager.gd`

---

# 3. 캐릭터 해금 — Crystal

`GameManager.gd`

```gdscript
const UNLOCK_COST := {
    "healer": 150,
    "tanker": 250,
    "buffer": 350,
}
```

각 숫자는 해당 캐릭터를 해금하는 데 필요한 **크리스탈(C)**입니다.

| 값 | 영향 |
|---|---|
| `healer` | 힐러 해금 가격 |
| `tanker` | 탱커 해금 가격 |
| `buffer` | 버퍼 해금 가격 |

딜러는 기본 해금 상태이므로 가격 항목이 없습니다.

---

# 4. 공용 업그레이드

`COMMON_UPGRADE_INFO`

각 업그레이드는 기본적으로 다음 값을 가집니다.

```text
per_level   = 1회 업그레이드당 증가량
base_cost   = 첫 업그레이드 비용
cost_growth = 업그레이드마다 비용이 증가하는 배율
```

## 4.1 전투 후 HP 회복 — Gold

`post_battle_heal_hp`

- `per_level` → 업그레이드 1회당 전투 후 HP 회복량 증가
- `base_cost` → 첫 업그레이드 가격
- `cost_growth` → 업그레이드 가격 증가율

## 4.2 전투 후 MP 회복 — Gold

`post_battle_heal_mp`

- `per_level` → 업그레이드 1회당 전투 후 MP 회복량 증가
- `base_cost` → 첫 업그레이드 가격
- `cost_growth` → 업그레이드 가격 증가율

## 4.3 던전 몬스터 강화율 감소 — Crystal

`dungeon_stat_reduction`

- `per_level` → 업그레이드 1회당 던전 몬스터 스탯 증가폭 감소량
- `base_cost` → 첫 업그레이드 가격(C)
- `cost_growth` → 업그레이드 가격 증가율

관련 기본값:

```gdscript
const STAT_MULTIPLIER_STEP_BASE := 2.0
```

던전 단계가 올라갈 때 몬스터 스탯 배율이 증가하는 기본 폭입니다.

값을 높이면 던전 난이도가 더 빠르게 상승합니다.

## 4.4 던전 보상 배율 증가 — Crystal

`dungeon_reward_boost`

- `per_level` → 업그레이드 1회당 던전 보상 증가폭
- `base_cost` → 첫 업그레이드 가격(C)
- `cost_growth` → 업그레이드 가격 증가율

관련 기본값:

```gdscript
const REWARD_MULTIPLIER_STEP_BASE := 3.0
```

던전 단계가 올라갈 때 보상 배율이 증가하는 기본 폭입니다.

값을 높이면 높은 던전의 보상이 더 빠르게 증가합니다.

## 4.5 배틀 속도 — Crystal

`battle_speed`

- `per_level` → 업그레이드 1회당 게임 속도 증가량
- `base_cost` → 첫 업그레이드 가격(C)
- `cost_growth` → 업그레이드 가격 증가율
- `max_level` → 최대 업그레이드 레벨

현재 기본 설정은 1레벨당 10% 증가, 최대 10레벨입니다.

게임 배속은 `Engine.time_scale`을 사용하므로 **애니메이션과 행동 간격 모두 함께 빨라집니다.**

---

# 5. 캐릭터 스탯 업그레이드 — Gold

`CHARACTER_UPGRADE_INFO`

캐릭터별로 HP / MP / ATK / DEF / SPD를 각각 조정할 수 있습니다.

예:

```gdscript
"dealer": {
    "hp":  {"per_level": 10, "base_cost": 15, "cost_growth": 1.15},
    "mp":  {"per_level": 5,  "base_cost": 15, "cost_growth": 1.15},
    "atk": {"per_level": 2,  "base_cost": 25, "cost_growth": 1.18},
    "def": {"per_level": 2,  "base_cost": 20, "cost_growth": 1.18},
    "spd": {"per_level": 1,  "base_cost": 30, "cost_growth": 1.2},
}
```

### 각 값의 의미

- `per_level` → 업그레이드 1회당 해당 스탯 증가량
- `base_cost` → 첫 업그레이드 비용(G)
- `cost_growth` → 업그레이드할 때마다 비용이 증가하는 배율

### 주의

여기서 수정하는 값은 **업그레이드로 얻는 증가량**입니다.

캐릭터의 기본 HP / ATK / DEF / SPD 자체를 바꾸려면 각 캐릭터의 `.tres` Resource를 Inspector에서 수정합니다.

---

# 6. 스킬 습득 — Crystal

`CHARACTER_SKILL_INFO`

스킬의:

```gdscript
"cost": 100
```

값은 해당 스킬을 **처음 배우는 데 필요한 크리스탈(C)**입니다.

현재 스킬 강화 비용과는 별개입니다.

---

# 7. 스킬 강화 — Gold

스킬마다 다음 값을 가집니다.

```text
power_per_level
upgrade_base_cost
upgrade_cost_growth
```

### `power_per_level`

스킬 업그레이드 1레벨당 스킬 위력 증가량입니다.

예:

```text
기본 power = 1.0
power_per_level = 0.1

0레벨 → 1.0
1레벨 → 1.1
2레벨 → 1.2
3레벨 → 1.3
```

### `upgrade_base_cost`

스킬 강화 첫 가격(G)입니다.

### `upgrade_cost_growth`

스킬 강화 가격이 레벨마다 증가하는 배율입니다.

---

# 8. 힐러 추가 회복 업그레이드 — Gold

힐러의 `hp_percent` 트랙은 별도의 회복량 증가 요소입니다.

```text
per_level
base_cost
cost_growth
```

### `per_level`

힐 대상의 최대 HP에 비례하여 추가 회복되는 양의 증가량입니다.

예를 들어 `0.05`라면 업그레이드 1레벨당 최대 HP의 5%가 추가됩니다.

---

# 9. 탱커 도발

관련 변수:

```gdscript
const TAUNT_DURATION_TURNS := 3
const TAUNT_BASE_WEIGHT := 1.0
```

### `TAUNT_DURATION_TURNS`

도발이 유지되는 턴 수입니다.

### `TAUNT_BASE_WEIGHT`

도발하지 않은 캐릭터의 기본 타겟 가중치입니다.

탱커의 도발 스킬 강화량은 `CHARACTER_SKILL_INFO`의 탱커 스킬 `power_per_level`에서 조정합니다.

---

# 10. 던전 난이도 및 보상

```gdscript
const STAT_MULTIPLIER_STEP_BASE := 2.0
const REWARD_MULTIPLIER_STEP_BASE := 3.0
```

### `STAT_MULTIPLIER_STEP_BASE`

던전 단계가 올라갈 때 적 스탯 증가에 사용되는 기본값입니다.

값을 높이면 던전 난이도가 더 빠르게 상승합니다.

### `REWARD_MULTIPLIER_STEP_BASE`

던전 단계가 올라갈 때 보상이 증가하는 기본값입니다.

값을 높이면 높은 던전의 보상이 더 빠르게 증가합니다.

---

# 11. 배속

`battle_speed`

현재 기본 설정:

```text
per_level = 10
max_level = 10
```

게임 속도 업그레이드 1레벨당 10%씩 증가하며 최대 10레벨까지 가능합니다.

`Engine.time_scale`을 사용하므로 애니메이션과 전투 행동 간격 모두 동일한 배속의 영향을 받습니다.

---

# 12. 행동 간 딜레이

`BattleManager.gd`

```gdscript
const ACTION_ANIMATION_PLACEHOLDER_DELAY := 0.3
const ACTION_DELAY := 0.2
```

### `ACTION_ANIMATION_PLACEHOLDER_DELAY`

행동 연출/애니메이션에 사용되는 시간입니다.

**애니메이션 자체의 속도를 조정하려는 경우 이 값을 수정합니다.**

### `ACTION_DELAY`

애니메이션이 끝난 뒤 **다음 캐릭터의 행동까지 추가로 기다리는 시간**입니다.

따라서 행동 템포만 조정하고 싶다면:

```gdscript
const ACTION_DELAY := 0.2
```

의 숫자를 수정합니다.

게임 배속은 이 두 시간 모두에 적용됩니다.

---

# 13. 빠른 밸런스 참고표

| 목표 | 수정 위치 | 재화 |
|---|---|---|
| 캐릭터 해금 가격 | `UNLOCK_COST` | C |
| 전투 후 HP 회복량 | `post_battle_heal_hp → per_level` | G |
| 전투 후 MP 회복량 | `post_battle_heal_mp → per_level` | G |
| 던전 적 강화 억제 | `dungeon_stat_reduction → per_level` | C |
| 던전 적 기본 강화폭 | `STAT_MULTIPLIER_STEP_BASE` | - |
| 던전 보상 증가 | `dungeon_reward_boost → per_level` | C |
| 던전 기본 보상 증가폭 | `REWARD_MULTIPLIER_STEP_BASE` | - |
| 게임 배속 증가량 | `battle_speed → per_level` | C |
| 게임 배속 최대 레벨 | `battle_speed → max_level` | C |
| 캐릭터 HP 업그레이드 | `CHARACTER_UPGRADE_INFO → hp → per_level` | G |
| 캐릭터 MP 업그레이드 | `CHARACTER_UPGRADE_INFO → mp → per_level` | G |
| 캐릭터 ATK 업그레이드 | `CHARACTER_UPGRADE_INFO → atk → per_level` | G |
| 캐릭터 DEF 업그레이드 | `CHARACTER_UPGRADE_INFO → def → per_level` | G |
| 캐릭터 SPD 업그레이드 | `CHARACTER_UPGRADE_INFO → spd → per_level` | G |
| 캐릭터 스탯 업그레이드 가격 | 해당 스탯의 `base_cost` | G |
| 캐릭터 스탯 가격 증가율 | 해당 스탯의 `cost_growth` | G |
| 스킬 습득 가격 | `CHARACTER_SKILL_INFO → cost` | C |
| 스킬 강화량 | `power_per_level` | G |
| 스킬 강화 첫 가격 | `upgrade_base_cost` | G |
| 스킬 강화 가격 증가율 | `upgrade_cost_growth` | G |
| 힐러 추가 회복 증가 | `hp_percent → per_level` | G |
| 도발 지속시간 | `TAUNT_DURATION_TURNS` | - |
| 기본 캐릭터 스탯 | 각 캐릭터 `.tres` Inspector | - |
| 행동 후 추가 대기 | `ACTION_DELAY` | - |
| 애니메이션 연출 시간 | `ACTION_ANIMATION_PLACEHOLDER_DELAY` | - |

---

# 14. 밸런스 작업 추천 순서

1. 캐릭터 `.tres`의 기본 스탯
2. 캐릭터 스탯 업그레이드 `per_level`
3. 스킬 기본 수치와 `power_per_level`
4. 스킬/스탯 업그레이드 가격
5. 캐릭터 및 스킬 해금 가격(C)
6. 던전 적 강화폭
7. 던전 보상 증가폭
8. 공용 업그레이드
9. 배틀 속도와 행동 템포

한 번에 모든 값을 바꾸기보다는 한 종류씩 조정하고 실제 플레이 시간과 재화 수급량을 비교하는 것을 권장합니다.
