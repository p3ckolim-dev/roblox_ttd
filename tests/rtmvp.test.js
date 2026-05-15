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
  assert.match(playerData, /DataStore unavailable; using session memory/);
});

test("shop, bench, merge, and synergy rules are represented in server modules", () => {
  const shop = read("src/server/Services/ShopService.lua");
  assert.match(shop, /SHOP_SIZE = 5/);
  assert.match(shop, /REROLL_COST = 2/);
  assert.match(shop, /BENCH_SIZE/);

  const board = read("src/server/Services/BoardService.lua");
  assert.match(board, /GRID_COLUMNS = 6/);
  assert.match(board, /GRID_ROWS = 4/);
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

test("client ui includes ready, shop, bench, board, wave, life, gold, interest, and synergies", () => {
  const client = read("src/client/ClientMain.client.lua");
  for (const label of ["Ready", "Shop", "Bench", "Board", "Wave", "Life", "Gold", "Interest", "Synergies"]) {
    assert.match(client, new RegExp(label));
  }
});

test("client ui exposes explicit shop, bench selection, grid placement, and reroll buttons", () => {
  const client = read("src/client/ClientMain.client.lua");
  assert.match(client, /ShopSlotButton/);
  assert.match(client, /BenchSlotButton/);
  assert.match(client, /GridCellButton/);
  assert.match(client, /selectedBenchSlot/);
  assert.match(client, /placeRemote:FireServer\(tower\.instanceId, row, column\)/);
  assert.match(client, /RerollButton/);
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
  assert.match(world, /TILE_GAP = 0\.55/);
  assert.match(world, /SURFACE_Y = 0\.35/);
  assert.match(world, /Enum\.Material\.Neon/);
  assert.match(world, /CellMarker/);
});

test("combat records attack events and world service visualizes enemies and beams", () => {
  const combat = read("src/server/Services/CombatService.lua");
  assert.match(combat, /board\.attackEvents/);
  assert.match(combat, /targetId = target\.id/);

  const board = read("src/server/Services/BoardService.lua");
  assert.match(board, /attackEvents = \{\}/);
  assert.match(board, /enemies = BoardService\.SerializeEnemies/);

  const world = read("src/server/Services/WorldService.lua");
  assert.match(world, /EnemyVisuals/);
  assert.match(world, /UpdateEnemyVisuals/);
  assert.match(world, /CreateAttackBeam/);
  assert.match(world, /pathPosition\(origin, enemy\.progress, board\.pathLength\)/);
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
  assert.match(match, /CombatService\.StepBoard\(board, COMBAT_STEP\)/);
  assert.match(match, /broadcastElapsed \+= COMBAT_STEP/);
});
