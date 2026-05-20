const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const root = path.resolve(__dirname, "..");

function read(relativePath) {
  return fs.readFileSync(path.join(root, relativePath), "utf8");
}

function extractLuaTableEntries(source, tableName) {
  const marker = `${tableName} = {`;
  const start = source.indexOf(marker);
  assert.notEqual(start, -1, `missing ${tableName} table`);

  let depth = 0;
  let bodyStart = -1;
  for (let index = start + marker.length - 1; index < source.length; index += 1) {
    const char = source[index];
    if (char === "{") {
      depth += 1;
      if (bodyStart === -1) bodyStart = index + 1;
    } else if (char === "}") {
      depth -= 1;
      if (depth === 0) {
        return source.slice(bodyStart, index);
      }
    }
  }

  throw new Error(`could not parse ${tableName}`);
}

function countKeyedEntries(tableBody) {
  return [...tableBody.matchAll(/\n\s+[A-Za-z][A-Za-z0-9_]*\s*=\s*\{/g)].length;
}

test("rojo project maps server, client, shared, and replicated storage roots", () => {
  const project = JSON.parse(read("default.project.json"));
  assert.equal(project.name, "TacticalTowerDefense");
  const game = project.tree;
  assert.ok(game.ReplicatedStorage.Shared, "Shared modules should replicate to clients");
  assert.ok(game.ServerScriptService.Server, "Server services should map into ServerScriptService");
  assert.ok(game.StarterPlayer.StarterPlayerScripts.Client, "Client scripts should map into StarterPlayerScripts");
});

test("tower data contains 24 original towers across 4 origins, 3 classes, and 5 rarities", () => {
  const source = read("src/shared/Config/TowerConfig.lua");
  const body = extractLuaTableEntries(source, "TowerConfig.Towers");
  assert.equal(countKeyedEntries(body), 24);

  for (const origin of ["Astral", "Ember", "Mech", "Wild"]) {
    assert.match(body, new RegExp(`origin = "${origin}"`));
  }

  for (const className of ["Marksman", "Arcanist", "Guardian"]) {
    assert.match(body, new RegExp(`class = "${className}"`));
  }

  for (const rarity of ["Common", "Rare", "Epic", "Legendary", "Mythic"]) {
    assert.match(body, new RegExp(`rarity = "${rarity}"`));
  }
});

test("wave data provides 30 waves with boss waves and the four MVP enemy types", () => {
  const enemySource = read("src/shared/Config/EnemyConfig.lua");
  const enemyBody = extractLuaTableEntries(enemySource, "EnemyConfig.Enemies");
  for (const enemyType of ["Basic", "Fast", "Tank", "Boss"]) {
    assert.match(enemyBody, new RegExp(`${enemyType}\\s*=`));
  }

  const waveSource = read("src/shared/Config/WaveConfig.lua");
  const generatedWaves = [...waveSource.matchAll(/for wave = 1, 30 do/g)].length;
  assert.equal(generatedWaves, 1, "waves should be generated for exactly 30 rounds");
  assert.match(waveSource, /isBoss = wave % 5 == 0/);
});

test("wave rules use 12 enemies in round one and 45 second timed rounds", () => {
  const waveSource = read("src/shared/Config/WaveConfig.lua");
  assert.match(waveSource, /WaveConfig\.RoundDurationSeconds = 45/);
  assert.match(waveSource, /count = wave == 1 and 12/);
  assert.match(waveSource, /durationSeconds = WaveConfig\.RoundDurationSeconds/);

  const waveService = read("src/server/Services/WaveService.lua");
  assert.doesNotMatch(waveService, /board\.enemies = \{\}/);
  assert.match(waveService, /table\.insert\(board\.enemies/);
});

test("waves spawn one enemy per second with the first enemy immediate", () => {
  const waveSource = read("src/shared/Config/WaveConfig.lua");
  assert.match(waveSource, /WaveConfig\.SpawnIntervalSeconds = 1/);
  assert.match(waveSource, /spawnInterval = WaveConfig\.SpawnIntervalSeconds/);

  const waveService = read("src/server/Services/WaveService.lua");
  assert.match(waveService, /local spawnDelay = \(index - 1\) \* wave\.spawnInterval/);
  assert.match(waveService, /progress = -spawnDelay \* enemyDefinition\.speed \* EnemyConfig\.SpeedMultiplier \* 4/);
});

test("core systems expose shop, merge, synergy, board, match, and combat services", () => {
  for (const file of [
    "src/server/Services/BoardService.lua",
    "src/server/Services/CombatService.lua",
    "src/server/Services/MatchService.lua",
    "src/server/Services/MergeService.lua",
    "src/server/Services/PlayerDataService.lua",
    "src/server/Services/ShopService.lua",
    "src/server/Services/SynergyService.lua",
    "src/server/Services/WorldService.lua",
    "src/server/Services/WaveService.lua",
  ]) {
    const source = read(file);
    assert.match(source, /return\s+[A-Za-z]+Service/);
  }
});

test("server bootstrap requires sibling services from script parent", () => {
  const serverMain = read("src/server/ServerMain.server.lua");
  assert.match(serverMain, /require\(script\.Parent\.Services\.MatchService\)/);
  assert.match(serverMain, /require\(script\.Parent\.Services\.PlayerDataService\)/);
});

test("player data service does not require datastore access during module load", () => {
  const playerData = read("src/server/Services/PlayerDataService.lua");
  assert.doesNotMatch(playerData, /local store = DataStoreService:GetDataStore/);
  assert.match(playerData, /getStore/);
  assert.match(playerData, /RunService = game:GetService\("RunService"\)/);
  assert.match(playerData, /RunService:IsStudio\(\)/);
  assert.doesNotMatch(playerData, /warn\("DataStore unavailable/);
});

test("shop, bench, merge, and synergy rules are represented in server modules", () => {
  const shop = read("src/server/Services/ShopService.lua");
  assert.match(shop, /SHOP_SIZE = 5/);
  assert.match(shop, /REROLL_COST = 2/);
  assert.match(shop, /BENCH_SIZE/);

  const board = read("src/server/Services/BoardService.lua");
  assert.match(board, /GRID_COLUMNS = 10/);
  assert.match(board, /GRID_ROWS = 10/);
  assert.match(board, /BENCH_SIZE = 8/);

  const merge = read("src/server/Services/MergeService.lua");
  assert.match(merge, /MERGE_COUNT = 3/);
  assert.match(merge, /AutoMerge/);
  assert.match(merge, /board\.mergeEvents/);
  assert.match(merge, /resultTowerId = resultTowerId/);

  const synergy = read("src/server/Services/SynergyService.lua");
  assert.match(synergy, /bench units do not count/i);
  assert.match(synergy, /Origins/);
  assert.match(synergy, /Classes/);
});

test("merge feedback is serialized, shown in hud, and visualized in world", () => {
  const board = read("src/server/Services/BoardService.lua");
  assert.match(board, /mergeEvents = \{\}/);
  assert.match(board, /mergeEvents = board\.mergeEvents/);

  const client = read("src/client/ClientMain.client.lua");
  assert.match(client, /MergeToast/);
  assert.match(client, /lastMergeEventId/);
  assert.match(client, /Merged/);

  const world = read("src/server/Services/WorldService.lua");
  assert.match(world, /CreateMergeBurst/);
  assert.match(world, /MergeBurst/);

  const match = read("src/server/Services/MatchService.lua");
  assert.match(match, /WorldService\.CreateMergeBurst\(board\)/);
});

test("client ui includes ready, shop, wave, timer, enemy count, gold, interest, and synergies", () => {
  const client = read("src/client/ClientMain.client.lua");
  for (const label of ["Ready", "Shop", "Wave", "Timer", "Enemies", "Gold", "Interest", "Synergies"]) {
    assert.match(client, new RegExp(label));
  }
});

test("client ui exposes shop and reroll while placement uses world clicks", () => {
  const client = read("src/client/ClientMain.client.lua");
  assert.match(client, /ShopSlotButton/);
  assert.match(client, /RerollButton/);
  assert.doesNotMatch(client, /BenchSlotButton/);
  assert.doesNotMatch(client, /GridCellButton/);
  assert.match(client, /mouse\.Button1Down:Connect/);
  assert.match(client, /TowerInstanceId/);
  assert.match(client, /placeRemote:FireServer\(selectedBenchTowerId, row, column\)/);
});

test("client ui shows tower rarity, origin, class, and active synergy emphasis", () => {
  const client = read("src/client/ClientMain.client.lua");
  assert.match(client, /TowerConfig = require\(ReplicatedStorage\.Shared\.Config\.TowerConfig\)/);
  assert.match(client, /RARITY_COLORS/);
  assert.match(client, /formatTowerCard/);
  assert.match(client, /definition\.origin/);
  assert.match(client, /definition\.class/);
  assert.match(client, /definition\.rarity/);
  assert.match(client, /ACTIVE/);
  assert.match(client, /Color3\.fromRGB\(78, 160, 255\)/);
});

test("world service creates primitive boards and tower visuals without toolbox assets", () => {
  const world = read("src/server/Services/WorldService.lua");
  assert.match(world, /Instance\.new\("Part"\)/);
  assert.match(world, /CreateBoardModel/);
  assert.match(world, /CreateTowerVisual/);
  assert.match(world, /GRID_COLUMNS/);
  assert.match(world, /GRID_ROWS/);
});

test("world board uses raised separated tiles to avoid z-fighting", () => {
  const world = read("src/server/Services/WorldService.lua");
  assert.match(world, /TILE_HEIGHT = 0\.45/);
  assert.match(world, /TILE_GAP = 0\.35/);
  assert.match(world, /SURFACE_Y = 0\.35/);
  assert.match(world, /Enum\.Material\.Neon/);
  assert.match(world, /CellMarker/);
});

test("world board is a 10 by 10 grid and includes physical bench slots", () => {
  const board = read("src/server/Services/BoardService.lua");
  assert.match(board, /GRID_COLUMNS = 10/);
  assert.match(board, /GRID_ROWS = 10/);
  assert.match(board, /PATH_LENGTH = 2 \* \(\(GRID_COLUMNS \+ 1\) \+ \(GRID_ROWS \+ 1\)\) \* 4/);

  const world = read("src/server/Services/WorldService.lua");
  assert.match(world, /CELL_SIZE = 6/);
  assert.match(world, /BenchSlot_/);
  assert.match(world, /SetAttribute\("BenchSlot"/);
  assert.match(world, /CreateBenchTowerVisual/);
  assert.match(world, /SetAttribute\("TowerInstanceId"/);
});

test("combat records attack events and world service visualizes enemies and beams", () => {
  const combat = read("src/server/Services/CombatService.lua");
  assert.match(combat, /board\.attackEvents/);
  assert.match(combat, /targetId = target\.id/);
  assert.match(combat, /targetProgress = target\.progress/);

  const board = read("src/server/Services/BoardService.lua");
  assert.match(board, /attackEvents = \{\}/);
  assert.match(board, /enemies = BoardService\.SerializeEnemies/);

  const world = read("src/server/Services/WorldService.lua");
  assert.match(world, /EnemyVisuals/);
  assert.match(world, /UpdateEnemyVisuals/);
  assert.match(world, /CreateAttackBeam/);
  assert.match(world, /pathPosition\(origin, enemy\.progress, board\.pathLength\)/);
});

test("attack visuals still render when the target dies in the same combat tick", () => {
  const world = read("src/server/Services/WorldService.lua");
  assert.match(world, /local function enemyPosition\(board, event\)/);
  assert.match(world, /event\.targetProgress/);
  assert.match(world, /pathPosition\(getBoardOrigin\(board\), event\.targetProgress, board\.pathLength\)/);
  assert.match(world, /AttackImpact/);
  assert.match(world, /Debris:AddItem\(beam, 0\.22\)/);
});

test("combat loops enemies around the side path and eliminates at 100 visible enemies", () => {
  const combat = read("src/server/Services/CombatService.lua");
  assert.match(combat, /enemy\.progress %= board\.pathLength/);
  assert.doesNotMatch(combat, /board\.life -= enemy\.lifeDamage/);
  assert.match(combat, /CombatService\.CountVisibleEnemies/);
  assert.match(combat, /board\.enemyLimit/);
  assert.match(combat, /board\.eliminated = true/);

  const board = read("src/server/Services/BoardService.lua");
  assert.match(board, /enemyLimit = 100/);
  assert.match(board, /aliveEnemyCount = board\.aliveEnemyCount/);
  assert.match(board, /function BoardService\.CountVisibleEnemies\(board\)/);
  assert.match(board, /enemy\.alive and enemy\.progress >= 0/);
});

test("match loop runs each wave by timer instead of clearing all enemies", () => {
  const match = read("src/server/Services/MatchService.lua");
  assert.match(match, /local waveElapsed = 0/);
  assert.match(match, /local waveDuration = waveConfig\.durationSeconds or 45/);
  assert.match(match, /waveElapsed < waveDuration/);
  assert.doesNotMatch(match, /CombatService\.IsWaveCleared\(board\)/);
});

test("match loop publishes round timer and keeps combat running during intermission", () => {
  const match = read("src/server/Services/MatchService.lua");
  assert.match(match, /START_COUNTDOWN = 3/);
  assert.match(match, /phase = "Lobby"/);
  assert.match(match, /timeRemaining = 0/);
  assert.match(match, /phaseDuration = 0/);
  assert.match(match, /phase = state\.phase/);
  assert.match(match, /timeRemaining = state\.timeRemaining/);
  assert.match(match, /local function stepActiveBoards\(deltaTime\)/);
  assert.match(match, /state\.phase = "Wave"/);
  assert.match(match, /state\.phase = "Intermission"/);
  assert.match(match, /state\.timeRemaining = math\.max\(0, START_COUNTDOWN - intermissionElapsed\)/);
  assert.match(match, /stepActiveBoards\(COMBAT_STEP\)/);
  assert.doesNotMatch(match, /task\.wait\(START_COUNTDOWN\)/);
});

test("match loop refreshes combat visuals every simulation tick", () => {
  const match = read("src/server/Services/MatchService.lua");
  assert.match(match, /WorldService\.RefreshCombat\(board\)/);
  const world = read("src/server/Services/WorldService.lua");
  assert.match(world, /board\.attackEvents = \{\}/);
});

test("combat visuals update more frequently than state broadcasts for smoother movement", () => {
  const match = read("src/server/Services/MatchService.lua");
  assert.match(match, /COMBAT_STEP = 0\.05/);
  assert.match(match, /STATE_BROADCAST_INTERVAL = 0\.2/);
  assert.match(match, /CombatService\.StepBoard\(board, deltaTime\)/);
  assert.match(match, /stepActiveBoards\(COMBAT_STEP\)/);
  assert.match(match, /broadcastElapsed \+= COMBAT_STEP/);
});

test("board snapshots include render metadata for client-side enemy interpolation", () => {
  const board = read("src/server/Services/BoardService.lua");
  assert.match(board, /pathLength = board\.pathLength/);
  assert.match(board, /worldOrigin = BoardService\.SerializeWorldOrigin\(board\)/);
  assert.match(board, /function BoardService\.SerializeWorldOrigin\(board\)/);
});

test("client renders enemies locally with RenderStepped interpolation", () => {
  const client = read("src/client/ClientMain.client.lua");
  assert.match(client, /RunService = game:GetService\("RunService"\)/);
  assert.match(client, /clientEnemyVisuals/);
  assert.match(client, /targetProgress/);
  assert.match(client, /currentProgress/);
  assert.match(client, /local function onRenderStep\(deltaTime\)/);
  assert.match(client, /updateClientEnemyVisuals\(deltaTime\)/);
  assert.match(client, /RunService\.RenderStepped:Connect\(onRenderStep\)/);
  assert.match(client, /pathPosition\(board\.worldOrigin, visualState\.currentProgress, board\.pathLength\)/);
});

test("client fixes camera to a birdview framing the local board", () => {
  const client = read("src/client/ClientMain.client.lua");
  assert.match(client, /local GRID_COLUMNS = 10/);
  assert.match(client, /local GRID_ROWS = 10/);
  assert.match(client, /BOARD_CAMERA_FOV/);
  assert.match(client, /Workspace\.CurrentCamera/);
  assert.match(client, /Enum\.CameraType\.Scriptable/);
  assert.match(client, /camera\.ViewportSize/);
  assert.match(client, /CFrame\.lookAt/);
  assert.match(client, /updateBoardCamera\(latestSnapshot and latestSnapshot\.board\)/);
});

test("client keeps the shop clear of bottom bench interactions and hides placement instructions", () => {
	const client = read("src/client/ClientMain.client.lua");
	assert.match(client, /ShopPanel", UDim2\.new\(1, -220, 0, 204\), UDim2\.fromOffset\(204, 300\)/);
	assert.match(client, /UDim2\.fromOffset\(184, 44\)/);
	assert.doesNotMatch(client, /ShopPanel", UDim2\.new\(0\.5, -215, 1, -140\)/);
	assert.match(client, /selectionStatusLabel\.Visible = false/);
	assert.doesNotMatch(client, /Click a waiting/);
});

test("match start creates a center start point and spawns each player on their own board center", () => {
	const world = read("src/server/Services/WorldService.lua");
	assert.match(world, /local function boardCenter\(origin\)/);
	assert.match(world, /StartPoint/);
	assert.match(world, /function WorldService\.BoardCenter\(board\)/);
	assert.match(world, /function WorldService\.SpawnPlayerAtBoardCenter\(player, board\)/);
	assert.match(world, /character:PivotTo\(CFrame\.new\(center \+ Vector3\.new\(0, 6, 0\)\)\)/);

	const match = read("src/server/Services/MatchService.lua");
	assert.match(match, /WorldService\.SpawnPlayerAtBoardCenter\(player, board\)/);
});

test("client enemy movement advances at constant speed between server snapshots", () => {
  const board = read("src/server/Services/BoardService.lua");
  assert.match(board, /speed = enemy\.speed/);

  const client = read("src/client/ClientMain.client.lua");
  assert.match(client, /visualState\.speed = enemy\.speed or visualState\.speed/);
  assert.match(client, /local simulatedProgress = visualState\.currentProgress \+ visualState\.speed \* deltaTime \* ENEMY_PROGRESS_SCALE/);
  assert.match(client, /local progressDelta = visualState\.targetProgress - simulatedProgress/);
  assert.match(client, /local correction = progressDelta \* ENEMY_CORRECTION_RATE \* deltaTime/);
});

test("enemy movement speed is tripled from the previous multiplier", () => {
  const enemy = read("src/shared/Config/EnemyConfig.lua");
  assert.match(enemy, /EnemyConfig\.SpeedMultiplier = 4\.5/);

  const wave = read("src/server/Services/WaveService.lua");
  assert.match(wave, /speed = enemyDefinition\.speed \* EnemyConfig\.SpeedMultiplier/);
  assert.match(wave, /progress = -spawnDelay \* enemyDefinition\.speed \* EnemyConfig\.SpeedMultiplier \* 4/);
});

test("client displays the match timer phase and remaining seconds", () => {
  const client = read("src/client/ClientMain.client.lua");
  assert.match(client, /TimerLabel/);
  assert.match(client, /local function formatTimer\(snapshot\)/);
  assert.match(client, /snapshot\.phase/);
  assert.match(client, /snapshot\.timeRemaining/);
  assert.match(client, /timerLabel\.Text = formatTimer\(snapshot\)/);
});

test("client placement UX shows selected tower, valid cells, occupied cells, and world previews", () => {
  const client = read("src/client/ClientMain.client.lua");
  assert.match(client, /SelectionStatusLabel/);
  assert.match(client, /UIStroke/);
  assert.match(client, /PLACEMENT_VALID_COLOR/);
  assert.match(client, /PLACEMENT_OCCUPIED_COLOR/);
  assert.match(client, /updatePlacementPreview/);
  assert.match(client, /PlacementPreview/);
  assert.match(client, /part\.CanQuery = false/);
});
