-- Initializing global variables to store the latest game state and game host process.
-- 初始化全局变量以存储最新的游戏状态和游戏主机进程。
LatestGameState = LatestGameState or nil
InAction = InAction or false -- Prevents the agent from taking multiple actions at once.
-- 防止代理一次执行多个操作。

Logs = Logs or {}

colors = {
  red = "\27[31m",
  green = "\27[32m",
  blue = "\27[34m",
  reset = "\27[0m",
  gray = "\27[90m"
}

function addLog(msg, text) -- Function definition commented for performance, can be used for debugging
-- 函数定义已注释以提高性能，可用于调试
  Logs[msg] = Logs[msg] or {}
  table.insert(Logs[msg], text)
end

-- Checks if two points are within a given range.
-- 检查两个点是否在给定范围内。
-- @param x1, y1: Coordinates of the first point.
-- @param x2, y2: Coordinates of the second point.
-- @param range: The maximum allowed distance between the points.
-- @return: Boolean indicating if the points are within the specified range.
-- @param x1, y1: 第一个点的坐标。
-- @param x2, y2: 第二个点的坐标。
-- @param range: 点之间允许的最大距离。
-- @return: 布尔值，表示点是否在指定范围内。

function inRange(x1, y1, x2, y2, range)
    return math.abs(x1 - x2) <= range and math.abs(y1 - y2) <= range
end

-- Decides the next action based on player proximity and energy.
-- 根据玩家的接近度和能量决定下一步行动。
-- If any player is within range, it initiates an attack; otherwise, moves randomly.
-- 如果任何玩家在范围内，则发起攻击；否则随机移动。
function decideNextAction()
  ao.send({Target = Game, Action = "GetGameState"})
  local player = LatestGameState.Players[ao.id]
  findNearestTarget()
  local target = CurrentTarget and LatestGameState.Players[CurrentTarget]

  if target then
      local targetInRange = inRange(player.x, player.y, target.x, target.y, 1)
      if player.energy > 5 and targetInRange then
          print(colors.red .. "Target in range. Attacking." .. colors.reset)
          ao.send({Target = Game, Action = "PlayerAttack", Player = ao.id, AttackEnergy = tostring(5)})
      elseif player.energy > 0 then
          local direction = determineDirection(player.x, player.y, target.x, target.y)
          print(colors.red .. "Moving towards target in direction: " .. direction .. colors.reset)
          ao.send({Target = Game, Action = "PlayerMove", Player = ao.id, Direction = direction})
      else
          print(colors.gray .. "Not enough energy to move or attack." .. colors.reset)
      end
  else
      print(colors.red .. "No target found. Moving randomly or re-evaluating strategy." .. colors.reset)
      -- Code to move randomly or re-evaluate strategy here
      -- 这里有随机移动或重新评估策略的代码
  end
  InAction = false
end
  
  function determineDirection(x1, y1, x2, y2)
    local horizontalMovement = x2 - x1
    local verticalMovement = y2 - y1
    local direction = ""
  
    if verticalMovement > 0 then
        direction = "Down"  -- Assuming positive Y is down
        -- 假设正Y方向向下
    elseif verticalMovement < 0 then
        direction = "Up"
        -- 向上
    end
  
    if horizontalMovement > 0 then
        direction = direction .. "Right"
        -- 向右
    elseif horizontalMovement < 0 then
        direction = direction .. "Left"
        -- 向左
    end
  
    return direction
  end
  
  
  
  -- Finds the nearest target and updates the CurrentTarget variable.
  -- 查找最近的目标并更新CurrentTarget变量。
  function findNearestTarget()
    local player = LatestGameState.Players[ao.id]
    local shortestDistance = math.huge
    local nearestTarget = nil

    for targetID, state in pairs(LatestGameState.Players) do
        if targetID ~= ao.id then
            local distance = math.sqrt((state.x - player.x)^2 + (state.y - player.y)^2)
            if distance < shortestDistance then
                shortestDistance = distance
                nearestTarget = targetID
            end
        end
    end

    CurrentTarget = nearestTarget
    if CurrentTarget then
        print(colors.blue .. "Locked on target ID: " .. CurrentTarget .. colors.reset)
    else
        print(colors.red .. "No target found within range." .. colors.reset)
        -- 范围内未找到目标。
    end
end

-- Handler for "Eliminated" events to trigger AutoPay
-- 处理“Eliminated”事件以触发自动支付
Handlers.add(
  "Eliminated-Autopay",
  Handlers.utils.hasMatchingTag("Action", "Eliminated"),
  function (msg)
    -- This will be triggered when an "Eliminated" event is received.
    -- 当收到“Eliminated”事件时将触发此功能。
    print(colors.red .. "Elimination detected. Triggering autopay to re-enter round." .. colors.reset)
    ao.send({ Target = CRED, Action = "Transfer", Recipient = Game, Quantity = "1000"})
  end
)

-- Handler to automate payment confirmation when waiting period starts.
-- 当等待期开始时自动化支付确认的处理程序。
--Handlers.add(
 -- "AutoPay",
 -- Handlers.utils.hasMatchingTag("Action", "AutoPay"),
 -- function (msg)
 --  InAction = false -- InAction logic added
  --  print("Auto-paying confirmation fees.")
   -- ao.send({ Target = CRED, Action = "Transfer", Recipient = Game, Quantity = "1000"})
 -- end
--)

-- This Handler will get the bot moving by updating the gamestate after payment confirmation is received
-- 此处理程序将在收到支付确认后通过更新游戏状态来启动机器人
Handlers.add(
  "Payment-GameState",
  Handlers.utils.hasMatchingTag("Action", "Payment-Received"),
  function (msg)
    print(colors.green .. "Waking up GRID Bot".. colors.reset)
    InAction = false
    Send({Target = Game, Action = "GetGameState", Name = Name , Owner = Owner})
  end
)

-- Handler to trigger game state updates.
-- 触发游戏状态更新的处理程序。
Handlers.add(
  "GetGameStateOnTick",
  Handlers.utils.hasMatchingTag("Action", "Tick"),
  function ()
      -- print(colors.gray .. "Getting game state..." .. colors.reset)
      -- 获取游戏状态...
      ao.send({Target = Game, Action = "GetGameState"})
  end
)


-- Handler to update the game state upon receiving game state information.
-- 接收到游戏状态信息时更新游戏状态的处理程序。
Handlers.add(
  "UpdateGameState",
  Handlers.utils.hasMatchingTag("Action", "GameState"),
  function (msg)
    local json = require("json")
    LatestGameState = json.decode(msg.Data)
    ao.send({Target = ao.id, Action = "UpdatedGameState"})
    --print(LatestGameState)
  end
)



-- Handler to decide the next best action.
-- 决定下一个最佳行动的处理程序。
Handlers.add(
  "decideNextAction",
  Handlers.utils.hasMatchingTag("Action", "UpdatedGameState"),
  function ()
    print("Looking around..")
    decideNextAction()
    ao.send({Target = ao.id, Action = "Tick"})
  end
)

-- Handler to automatically attack when hit by another player.
-- 当被其他玩家击中时自动攻击的处理程序。
Handlers.add(
  "ReturnAttack",
  Handlers.utils.hasMatchingTag("Action", "Hit"),
  function (msg)
    local playerEnergy = LatestGameState.Players[ao.id].energy
    if playerEnergy < 5 then
      print(colors.red .. "Player Is too tired." .. colors.reset)
      -- 玩家太累了。
    else
      print(colors.red .. "Returning attack..." .. colors.reset)
      -- 返回攻击...
      ao.send({Target = Game, Action = "PlayerAttack", AttackEnergy = tostring(playerEnergy)})
    end
    ao.send({Target = ao.id, Action = "Tick"})
  end
)

Handlers.add(
  "Withdraw-Winnings",
  function (msg)
    -- only run the handle function if the msg has a Action of Credit-Notice and is from the Game process
    -- 如果消息具有Credit-Notice动作并来自游戏进程，则只运行处理函数
    -- even if this handler is run, continue down the stack so it can be processed or added to inbox
    -- 即使运行此处理程序，也继续向下执行，以便可以处理或添加到收件箱中
    return msg.Action == "Credit-Notice" and msg.From == Game and "continue" or false
  end,
  function (msg)
    print(colors.green .. "Taking Winnings" .. colors.reset)
    -- 领取奖金
    ao.send({Target = Game, Action = "Withdraw"})
  end
)

Handlers.add(
  "AutoSpawner",
  Handlers.utils.hasMatchingTag("Action", "Removed"),
  function (msg)
    print("Auto-paying confirmation fees.")
    -- 自动支付确认费用。
    ao.send({ Target = CRED, Action = "Transfer", Recipient = Game, Quantity = "1000"})
  end
)