-- ai/core.lua
-- 适用于CS 1.6无限子弹僵尸感染的AI核心文件

dofile "ai/vector.lua" 
dofile "ai/shared.lua"
dofile "ai/protocol.lua"

dofile "ai/think.lua"

-- 僵尸感染模式特定变量
IsZombie = false
IsHuman = true
LastInfectionTime = 0
INFECTION_COOLDOWN = 5 -- 感染冷却时间(秒)

function Initialization()
	math.randomseed(os.time())

	LastKnownWeapon = GetWeaponByAbsoluteIndex(GetWeaponAbsoluteIndex())
	IsSpawned = IsAlive()
	
	-- CS 1.6特定初始化
	if GetGameDir() == "cstrike" then
		-- 随机选择玩家模型
		local models = {"terror", "urban", "gsg9", "sas"}
		ExecuteCommand("model " .. models[math.random(#models)])
		
		-- 设置随机颜色
		ExecuteCommand("topcolor " .. math.random(255))
		ExecuteCommand("bottomcolor " .. math.random(255))
		
		-- 初始设置为人类
		IsZombie = false
		IsHuman = true
	end
	
	if Idle then
		print "Idle mode"
	end
end

function Finalization()
	
end

function Frame() 
	if GetIntermission() ~= 0 then -- 地图结束?
		return
	end
	
	if IsPaused() then
		return
	end
	
	-- 检查是否被感染
	if IsHuman and IsAlive() then
		CheckForInfection()
	end
	
	PreThink()
	Think()
	PostThink()
	
	-- 无限子弹处理
	if IsHuman and IsAlive() and not IsZombie then
		RefillAmmo()
	end
end

function CheckForInfection()
	-- 检查周围是否有僵尸
	local entities = GetEntities()
	for i, ent in ipairs(entities) do
		if ent.Valid and ent.IsPlayer and ent.Team ~= GetTeam() and ent.Health > 0 then
			local dist = GetDistance(ent.Origin)
			if dist < 150 then -- 感染距离
				-- 检查冷却时间
				if CurTime() - LastInfectionTime > INFECTION_COOLDOWN then
					InfectPlayer()
					LastInfectionTime = CurTime()
					break
				end
			end
		end
	end
end

function InfectPlayer()
	-- 被感染成为僵尸
	IsZombie = true
	IsHuman = false
	
	-- 切换到刀作为武器
	ExecuteCommand("use weapon_knife")
	
	-- 增加生命值作为僵尸
	SetHealth(2500)
	
	-- 通知服务器玩家被感染
	ServerCommand("say I've been infected! I'm now a zombie!")
end

function RefillAmmo()
	-- 无限子弹实现
	local weapon = GetActiveWeapon()
	if weapon and weapon.Valid then
		-- 为当前武器填满弹药
		SetAmmo(weapon.PrimaryAmmoType, 999)
		SetAmmo(weapon.SecondaryAmmoType, 999)
		
		-- 特殊处理某些武器
		if weapon.Classname == "weapon_m249" then
			SetAmmo(weapon.PrimaryAmmoType, 200)
		end
	end
end

function OnTrigger(ATrigger)
	if ATrigger == "RoundStart" then
		IsEndOfRound = false
		IsZombie = false
		IsHuman = true
		Spawn()
	elseif ATrigger == "RoundEnd" then
		IsEndOfRound = true
	elseif ATrigger == "InfectionStart" then
		-- 感染模式开始
		print("Infection mode started!")
	elseif ATrigger == "PlayerInfected" then
		-- 玩家被感染
		InfectPlayer()
	else
		print("Unknown trigger: " .. ATrigger)
	end
end

-- 重写Think函数以适应僵尸感染模式
function Think()
	if IsZombie then
		ZombieThink()
	else
		HumanThink()
	end
end

function ZombieThink()
	-- 僵尸AI逻辑
	-- 寻找最近的人类玩家
	local target = FindNearestHuman()
	if target and target.Valid then
		-- 移动到目标
		MoveTo(target.Origin)
		
		-- 接近时攻击
		local dist = GetDistance(target.Origin)
		if dist < 150 then
			Attack()
		end
	else
		-- 没有目标时随机移动
		Wander()
	end
end

function HumanThink()
	-- 人类AI逻辑
	-- 寻找最近的僵尸
	local zombie = FindNearestZombie()
	if zombie and zombie.Valid then
		local dist = GetDistance(zombie.Origin)
		if dist < 500 then
			-- 远离僵尸
			MoveAwayFrom(zombie.Origin)
			
			-- 射击僵尸
			if dist < 2000 then
				AimAt(zombie.Origin)
				Attack()
			end
		else
			-- 没有附近僵尸时随机移动
			Wander()
		end
	else
		-- 没有僵尸时随机移动
		Wander()
	end
end
