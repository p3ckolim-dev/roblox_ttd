# Random Tower Defense

Rojo-based Roblox MVP for a personal-lane random tower defense game with TFT-inspired original synergies.

## MVP Loop

- Lobby ready flow supports solo start and up to 6 players.
- Each player gets a personal outer-loop lane and a central 6x4 tower board.
- Towers are bought from a 5-slot paid-reroll shop, placed from an 8-slot bench, and auto-merged in sets of three.
- Server modules own match state, waves, economy, combat, merges, synergies, ranking, and persistence.
- Client UI displays Ready, Shop, Bench, Board, Wave, Life, Gold, Interest, and Synergies.

## Local Checks

```sh
npm test
```

Roblox Studio/Rojo execution is expected once `rojo` is installed locally.
